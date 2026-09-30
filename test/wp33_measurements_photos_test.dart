import 'dart:convert';
// ══════════════════════════════════════════════════════════════════
// Phase 3 — WP3.3 data-consistency tests
// Body Measurements (§45) + Progress Photo metadata (§46)
// Pure Dart; no Flutter bindings needed beyond ThemeMode in store.
// ══════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_app/data/measurements.dart';
import 'package:pulse_app/data/persistence/local_backend.dart';
import 'package:pulse_app/data/progress_photos.dart';
import 'package:pulse_app/data/pulse_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MeasurementBook (pure domain)', () {
    test('logs values and computes trend vs previous entry', () {
      final b = MeasurementBook();
      expect(b.log('waist', DateTime(2026, 9, 1), 91.0), isTrue);
      expect(b.log('waist', DateTime(2026, 9, 15), 88.0), isTrue);
      final t = measurementTrend(b.historyFor('waist'));
      expect(t.hasPrevious, isTrue);
      expect(t.delta, closeTo(-3.0, 1e-9));
    });

    test('same-day re-entry replaces instead of duplicating', () {
      final b = MeasurementBook();
      b.log('chest', DateTime(2026, 9, 29, 8), 101.0);
      b.log('chest', DateTime(2026, 9, 29, 20), 102.5);
      final h = b.historyFor('chest');
      expect(h.length, 1);
      expect(h.single.value, 102.5);
    });

    test('rejects unknown site and invalid values', () {
      final b = MeasurementBook();
      expect(b.log('nope', DateTime(2026, 9, 1), 50), isFalse);
      expect(b.log('waist', DateTime(2026, 9, 1), 0), isFalse);
      expect(b.log('waist', DateTime(2026, 9, 1), -5), isFalse);
      expect(b.log('waist', DateTime(2026, 9, 1), double.nan), isFalse);
      expect(b.historyFor('waist'), isEmpty);
    });

    test('custom sites dedupe by label (case-insensitive)', () {
      final b = MeasurementBook();
      expect(b.addSite(const MeasurementSite(id: 'calves', label: 'Calves', unit: 'cm')), isTrue);
      expect(b.addSite(const MeasurementSite(id: 'calves2', label: 'calves', unit: 'cm')), isFalse);
      expect(b.sites.length, kDefaultMeasurementSites.length + 1);
    });

    test('JSON round-trip preserves history + custom sites', () {
      final b = MeasurementBook();
      b.addSite(const MeasurementSite(id: 'calves', label: 'Calves', unit: 'cm', lowerIsBetter: false));
      b.log('calves', DateTime(2026, 9, 2), 39.5);
      b.log('body_fat', DateTime(2026, 9, 2), 21.4);
      final copy = MeasurementBook()..hydrate(jsonRoundTrip(b.toJson()));
      expect(copy.latestFor('calves')!.value, 39.5);
      expect(copy.latestFor('body_fat')!.value, 21.4);
      expect(copy.sites.length, b.sites.length);
    });

    test('eraseAll keeps built-in sites but clears history/customs', () {
      final b = MeasurementBook();
      b.addSite(const MeasurementSite(id: 'calves', label: 'Calves', unit: 'cm'));
      b.log('waist', DateTime(2026, 9, 1), 90);
      b.eraseAll();
      expect(b.historyFor('waist'), isEmpty);
      expect(b.sites.length, kDefaultMeasurementSites.length);
    });

    test('seeded store history matches brief values (§45)', () {
      final b = MeasurementBook();
      for (final (id, mo, v) in const <(String, int, double)>[
        ('body_fat', 6, 23.5), ('body_fat', 9, 21.4),
        ('waist', 6, 94), ('waist', 9, 88)]) {
        b.log(id, DateTime(2026, mo, 15), v);
      }
      expect(b.latestFor('waist')!.value, 88);
      expect(measurementTrend(b.historyFor('waist')).delta, closeTo(-6, 1e-9));
    });
  });

  group('ProgressPhotoBook (pure domain)', () {
    ProgressPhoto p(String id, int m, PhotoPose pose) => ProgressPhoto(
        id: id, date: DateTime(2026, m, 1), pose: pose, fileName: '$id.jpg', weightKgAtCapture: 80.0 + m);

    test('photos sort oldest→newest; comparisonPair gives first/last', () {
      final b = ProgressPhotoBook();
      b.add(p('c', 9, PhotoPose.front));
      b.add(p('a', 7, PhotoPose.front));
      b.add(p('b', 8, PhotoPose.front));
      final pair = b.comparisonPair(PhotoPose.front)!;
      expect(pair.$1.id, 'a');
      expect(pair.$2.id, 'c');
      expect(b.forPose(PhotoPose.side), isEmpty);
      expect(b.comparisonPair(PhotoPose.side), isNull); // <2 captures
    });

    test('remove returns file name for atomic disk cleanup', () {
      final b = ProgressPhotoBook();
      b.add(p('x', 8, PhotoPose.back));
      expect(b.remove('x'), 'x.jpg');
      expect(b.remove('missing'), isNull);
      expect(b.all, isEmpty);
    });

    test('JSON round-trip drops malformed records but keeps valid ones', () {
      final b = ProgressPhotoBook();
      b.add(p('k', 8, PhotoPose.side));
      final json = jsonRoundTrip(b.toJson());
      (json['photos'] as List).add({'id': 'bad'}); // missing fields
      final copy = ProgressPhotoBook()..hydrate(json.cast<String, dynamic>());
      expect(copy.all.length, 1);
      expect(copy.all.single.pose, PhotoPose.side);
    });
  });

  group('PulseStore integration (schema v3 persistence)', () {
    Future<PulseStore> freshStore() async {
      SharedPreferences.setMockInitialValues({});
      final repo = SharedPreferencesLocalRepository();
      final s = PulseStore();
      await s.initLocal(repo);
      return s;
    }

    test('measurement log survives restart with identical totals', () async {
      final s = await freshStore();
      expect(s.logMeasurement('waist', 88.0), isTrue);
      expect(s.logMeasurement('body_fat', 21.4), isTrue);
      await s.flushPendingSave();

      final s2 = PulseStore();
      await s2.initLocal(SharedPreferencesLocalRepository());
      expect(s2.measurements.latestFor('waist')!.value, 88.0);
      expect(s2.measurements.latestFor('body_fat')!.value, 21.4);
    });

    test('invalid measurement returns false and does not dirty state', () async {
      final s = await freshStore();
      final before = jsonEncode(s.toSnapshot()['measurements']);
      expect(s.logMeasurement('waist', -1.0), isFalse);
      expect(s.logMeasurement('ghost', 50.0), isFalse);
      expect(jsonEncode(s.toSnapshot()['measurements']), before); // byte-identical
    });

    test('photo metadata persists; image bytes never enter snapshot', () async {
      final s = await freshStore();
      s.addProgressPhoto(PhotoPose.front, 'private_docs/img_001.jpg',
          onDate: DateTime(2026, 9, 29));
      final snapJson = jsonEncode(s.toSnapshot());
      expect(snapJson.contains('img_001.jpg'), isTrue); // filename kept
      expect(snapJson.contains('/9j/4AAQ'), isFalse); // no base64 jpeg payloads
      await s.flushPendingSave();

      final s2 = PulseStore();
      await s2.initLocal(SharedPreferencesLocalRepository());
      expect(s2.progressPhotos.all.single.pose, PhotoPose.front);
      expect(s2.progressPhotos.all.single.weightKgAtCapture, isNotNull);
    });

    test('deleteAllLocalData erases measurements AND photo records (§60)', () async {
      final s = await freshStore();
      s.logMeasurement('waist', 88);
      s.addMeasurementSite('Calves');
      s.addProgressPhoto(PhotoPose.back, 'b.jpg');
      await s.deleteAllLocalData();
      expect(s.measurements.historyFor('waist'), isEmpty); // seed erased too
      expect(s.measurements.sites.length, kDefaultMeasurementSites.length);
      expect(s.progressPhotos.all, isEmpty);
      // and it stays erased after a restart
      final s2 = PulseStore();
      await s2.initLocal(SharedPreferencesLocalRepository());
      expect(s2.measurements.historyFor('waist'), isEmpty);
      expect(s2.progressPhotos.all, isEmpty);
    });

    test('v2 snapshot without measurements/photos hydrates to defaults', () async {
      // Simulate an upgrade: hand-write an older snapshot shape.
      SharedPreferences.setMockInitialValues({});
      final repo = SharedPreferencesLocalRepository();
      await repo.init();
      await repo.writeSnapshot({
        'schemaVersion': 2,
        'revision': 1,
        'savedAt': DateTime.now().toIso8601String(),
        'goals': {'calorie': 2100},
        'water': 1.0,
      });
      final s = PulseStore();
      await s.initLocal(SharedPreferencesLocalRepository());
      expect(s.goals.calorieGoal, 2100); // old data still loads
      expect(s.measurements.sites.length, kDefaultMeasurementSites.length);
      expect(s.progressPhotos.all, isEmpty);
    });

    test('export bundle includes new sections for Download My Data', () async {
      final s = await freshStore();
      s.logMeasurement('hips', 99.0);
      final exported = jsonDecode(s.exportUserDataJson()) as Map<String, dynamic>;
      expect(exported['schemaVersion'], 3);
      // seed dates land on the 15th, so a fresh log creates a new day entry
      expect(((exported['measurements'] as Map)['history'] as Map)['hips'], hasLength(3));
    });
  });
}

/// Encode→decode through real JSON so Int/double/String typing matches
/// exactly what comes back from disk (catches `as int` vs `as double` bugs).
Map<String, dynamic> jsonRoundTrip(Map<String, dynamic> m) =>
    (jsonDecode(jsonEncode(m)) as Map).cast<String, dynamic>();
