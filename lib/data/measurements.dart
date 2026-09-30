// ══════════════════════════════════════════════════════════════════
// WP3.3a — Body Measurements domain (§45)
//
// Pure Dart, fully unit-testable, persistence-backed through the
// Phase-2 snapshot (schema v3). Same-day upsert semantics mirror the
// weight log: one record per (site, day) so re-entering today's waist
// updates it instead of duplicating history.
//
// Units are stored canonically in metric (cm / %); display conversion
// is a UI concern (WP3.2 units service will consume these values).
// ══════════════════════════════════════════════════════════════════

/// A single measurement site definition. [unit] is canonical metric;
/// `isPercent` sites (body fat) render with `%` and never convert to cm.
class MeasurementSite {
  final String id; // stable key persisted in snapshots
  final String label; // "Waist"
  final String unit; // 'cm' | '%'
  final bool lowerIsBetter; // for trend coloring in the UI
  final bool builtIn;

  const MeasurementSite({
    required this.id,
    required this.label,
    required this.unit,
    this.lowerIsBetter = true,
    this.builtIn = false,
  });

  bool get isPercent => unit == '%';
}

/// Default sites from the brief §45 (weight itself lives in the weight
/// log, not here — this table covers tape-measure + composition data).
const kDefaultMeasurementSites = <MeasurementSite>[
  MeasurementSite(id: 'body_fat', label: 'Body Fat %', unit: '%', builtIn: true),
  MeasurementSite(id: 'waist', label: 'Waist', unit: 'cm', builtIn: true),
  MeasurementSite(id: 'chest', label: 'Chest', unit: 'cm', lowerIsBetter: false, builtIn: true),
  MeasurementSite(id: 'hips', label: 'Hips', unit: 'cm', builtIn: true),
  MeasurementSite(id: 'arms', label: 'Arms', unit: 'cm', lowerIsBetter: false, builtIn: true),
  MeasurementSite(id: 'thighs', label: 'Thighs', unit: 'cm', lowerIsBetter: false, builtIn: true),
  MeasurementSite(id: 'neck', label: 'Neck', unit: 'cm', lowerIsBetter: false, builtIn: true),
];

/// One dated value for a site.
class MeasurementRecord {
  final DateTime date; // normalized to day granularity
  final double value; // canonical unit (cm or %)

  const MeasurementRecord(this.date, this.value);

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'value': value,
      };

  static MeasurementRecord? fromJson(Map<dynamic, dynamic> j) {
    final d = DateTime.tryParse('${j['date']}');
    final v = (j['value'] as num?)?.toDouble();
    if (d == null || v == null) return null;
    return MeasurementRecord(d, v);
  }
}

/// Day-granular key helper shared with tests ("2026-09-29").
String measurementDayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Change vs the previous entry: (delta, hasPrevious). Delta is signed
/// latest − previous in canonical units.
({double delta, bool hasPrevious}) measurementTrend(List<MeasurementRecord> history) {
  if (history.length < 2) return (delta: 0, hasPrevious: false);
  return (
    delta: history[history.length - 1].value - history[history.length - 2].value,
    hasPrevious: true,
  );
}

/// The mutable measurement book: sites (built-in + custom) each with a
/// sorted, de-duplicated (per day) history.
class MeasurementBook {
  final List<MeasurementSite> _sites = [...kDefaultMeasurementSites];
  final Map<String, List<MeasurementRecord>> _history = {};

  List<MeasurementSite> get sites => List.unmodifiable(_sites);

  List<MeasurementRecord> historyFor(String siteId) =>
      List.unmodifiable(_history[siteId] ?? const []);

  MeasurementRecord? latestFor(String siteId) {
    final h = _history[siteId];
    return (h == null || h.isEmpty) ? null : h.last;
  }

  /// Add a custom site. Returns false on duplicate id/label (case-insensitive).
  bool addSite(MeasurementSite site) {
    final dup = _sites.any((s) =>
        s.id == site.id || s.label.toLowerCase() == site.label.toLowerCase());
    if (dup) return false;
    _sites.add(site);
    return true;
  }

  /// Log (or same-day replace) a value. Validates positivity.
  /// Returns false when the site is unknown or the value is invalid.
  bool log(String siteId, DateTime date, double value) {
    if (!_sites.any((s) => s.id == siteId)) return false;
    if (!value.isFinite || value <= 0 || value > 1000) return false;
    final key = measurementDayKey(date);
    final list = _history.putIfAbsent(siteId, () => []);
    for (var i = 0; i < list.length; i++) {
      if (measurementDayKey(list[i].date) == key) {
        list[i] = MeasurementRecord(list[i].date, value); // keep first-seen time
        return true;
      }
    }
    list.add(MeasurementRecord(date, value));
    list.sort((a, b) => a.date.compareTo(b.date));
    return true;
  }

  void deleteHistoryEntry(String siteId, int index) {
    _history[siteId]?.removeAt(index.clamp(0, (_history[siteId]?.length ?? 1) - 1));
  }

  /// §60 erasure: drop custom sites + all history (built-in list returns).
  void eraseAll() {
    _sites.removeWhere((s) => !s.builtIn);
    _history.clear();
  }

  // ── Snapshot round-trip ───────────────────────────────────────────
  Map<String, dynamic> toJson() => {
        'customSites': [
          for (final s in _sites.where((s) => !s.builtIn))
            {'id': s.id, 'label': s.label, 'unit': s.unit, 'lowerIsBetter': s.lowerIsBetter},
        ],
        'history': {
          for (final e in _history.entries)
            if (e.value.isNotEmpty) e.key: [for (final r in e.value) r.toJson()],
        },
      };

  void hydrate(Map<String, dynamic>? json) {
    if (json == null) return;
    final custom = json['customSites'];
    if (custom is List) {
      for (final c in custom.whereType<Map>()) {
        final id = c['id'], label = c['label'], unit = c['unit'];
        if (id is! String || label is! String || unit is! String) continue;
        addSite(MeasurementSite(
            id: id, label: label, unit: unit, lowerIsBetter: c['lowerIsBetter'] as bool? ?? true));
      }
    }
    final hist = json['history'];
    if (hist is Map) {
      for (final e in hist.entries) {
        if (e.key is! String || e.value is! List) continue;
        final parsed = <MeasurementRecord>[];
        for (final r in (e.value as List).whereType<Map>()) {
          final rec = MeasurementRecord.fromJson(r);
          if (rec != null) parsed.add(rec);
        }
        parsed.sort((a, b) => a.date.compareTo(b.date));
        if (parsed.isNotEmpty) _history[e.key as String] = parsed;
      }
    }
  }
}
