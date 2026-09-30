import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════════════
/// PULSE LOCAL BACKEND — Phase 2 (persistence layer)
///
/// Architecture (local-first, no external DB):
///
///   PulseStore  ──(snapshot JSON)──▶  LocalRepository (interface)
///                                          │
///                              SharedPreferencesLocalRepository
///                                          │
///                                    platform storage (prefs)
///
/// Guarantees tested in test/persistence_test.dart:
///  * round-trip consistency: write → reload → identical state
///  * schema-versioned snapshots (future migrations hook)
///  * single-key commit + revision counter metadata
///  * corrupt-data recovery (falls back to defaults, never crashes)
///  * debounced autosave so rapid logging doesn't thrash I/O
///  * privacy: everything stays on-device; nothing leaves the app
/// ═══════════════════════════════════════════════════════════════════

// v2: additive `workouts` block (WP3.1 session engine). v1 snapshots
// still load — the block is optional and defaults to empty history.
const int kPulseSchemaVersion = 2;
const String kSnapshotKey = 'pulse.snapshot.v1';
const String kMetaKey = 'pulse.meta.v1';

/// Repository contract. Swap the implementation (prefs → sqflite → file)
/// without touching the store or UI layers.
abstract class LocalRepository {
  Future<void> init();
  /// Returns decoded snapshot map, or null when nothing is stored yet
  /// or the stored payload fails validation.
  Future<Map<String, dynamic>?> readSnapshot();
  Future<void> writeSnapshot(Map<String, dynamic> snapshot);
  Future<void> clearAll();
}

class SharedPreferencesLocalRepository implements LocalRepository {
  SharedPreferencesLocalRepository({this.filePrefix});

  /// Optional namespace so multiple profiles can coexist later.
  final String? filePrefix;

  late SharedPreferences _prefs;

  String _k(String key) => filePrefix == null ? key : '$filePrefix.$key';

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  Future<Map<String, dynamic>?> readSnapshot() async {
    final raw = _prefs.getString(_k(kSnapshotKey));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      // Schema guard: refuse to hydrate from an unknown future version.
      final meta = _prefs.getString(_k(kMetaKey));
      if (meta != null && meta.isNotEmpty) {
        final m = jsonDecode(meta);
        if (m is Map && m['schemaVersion'] is int &&
            (m['schemaVersion'] as int) > kPulseSchemaVersion) {
          return null;
        }
      }
      return decoded;
    } catch (_) {
      // Corrupt payload → treat as empty rather than crash the app.
      return null;
    }
  }

  @override
  Future<void> writeSnapshot(Map<String, dynamic> snapshot) async {
    final encoded = jsonEncode(snapshot);
    await _prefs.setString(_k(kSnapshotKey), encoded);
    final rev = (_prefs.getInt(_k('rev')) ?? 0) + 1;
    await _prefs.setInt(_k('rev'), rev);
    await _prefs.setString(
      _k(kMetaKey),
      jsonEncode({
        'schemaVersion': kPulseSchemaVersion,
        'revision': rev,
        'savedAt': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  @override
  Future<void> clearAll() async {
    await _prefs.remove(_k(kSnapshotKey));
    await _prefs.remove(_k(kMetaKey));
    await _prefs.remove(_k('rev'));
  }
}

/// Debounced autosave coordinator. Screens call [request] after every
/// mutation; the actual disk write happens at most once per [interval],
/// and [flush] forces completion of all pending saves (app backgrounding).
class AutosaveCoordinator {
  AutosaveCoordinator({
    required this.repository,
    required this.buildSnapshot,
    this.interval = const Duration(milliseconds: 400),
  });

  final LocalRepository repository;
  final Map<String, dynamic> Function() buildSnapshot;

  final Duration interval;
  Timer? _timer;
  bool _dirty = false;
  Future<void>? _inFlight;

  bool get isDirty => _dirty;

  void request() {
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(interval, () => flush());
  }

  /// Drop any scheduled write and dirty flag (used by data deletion so
  /// a wipe isn't immediately followed by an autosave rewrite).
  void cancelPending() {
    _timer?.cancel();
    _timer = null;
    _dirty = false;
  }

  /// Completes once all pending writes are on disk (including writes
  /// requested while this flush was in flight).
  Future<void> flush() async {
    _timer?.cancel();
    while (_dirty) {
      if (_inFlight != null) {
        await _inFlight;
        continue;
      }
      final snap = buildSnapshot();
      _dirty = false; // cleared before write; new edits re-mark it
      _inFlight = repository.writeSnapshot(snap).whenComplete(() {
        _inFlight = null;
      });
      await _inFlight;
    }
  }

  void dispose() => _timer?.cancel();
}
