// ══════════════════════════════════════════════════════════════════
// WP3.3b — Progress Photo metadata (§46)
//
// Privacy-first design: this book stores ONLY metadata (date, pose,
// weight-at-capture, file name). Image bytes live in the app's private
// documents directory and are never part of the JSON snapshot or the
// "Download My Data" export unless the user explicitly opts in.
// The UI must always render the banner:
//   "Private — visible only to you"
// ══════════════════════════════════════════════════════════════════

enum PhotoPose { front, side, back }

String photoPoseLabel(PhotoPose p) => switch (p) {
      PhotoPose.front => 'Front',
      PhotoPose.side => 'Side',
      PhotoPose.back => 'Back',
    };

PhotoPose? _poseFromName(String? n) => switch (n) {
      'front' => PhotoPose.front,
      'side' => PhotoPose.side,
      'back' => PhotoPose.back,
      _ => null,
    };

class ProgressPhoto {
  final String id;
  final DateTime date;
  final PhotoPose pose;
  final double? weightKgAtCapture; // denormalized for caption rendering
  final String fileName; // relative to private documents dir

  const ProgressPhoto({
    required this.id,
    required this.date,
    required this.pose,
    required this.fileName,
    this.weightKgAtCapture,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'pose': pose.name,
        'fileName': fileName,
        if (weightKgAtCapture != null) 'weightKg': weightKgAtCapture,
      };

  static ProgressPhoto? fromJson(Map<dynamic, dynamic> j) {
    final id = j['id'], file = j['fileName'];
    final d = DateTime.tryParse('${j['date']}');
    final pose = _poseFromName(j['pose'] as String?);
    if (id is! String || file is! String || d == null || pose == null) return null;
    return ProgressPhoto(
      id: id,
      date: d,
      pose: pose,
      fileName: file,
      weightKgAtCapture: (j['weightKg'] as num?)?.toDouble(),
    );
  }
}

/// Metadata-only registry. Oldest→newest ordering is maintained so the
/// comparison slider can simply take first/last of a pose list.
class ProgressPhotoBook {
  final List<ProgressPhoto> _photos = [];

  List<ProgressPhoto> get all => List.unmodifiable(_photos);

  List<ProgressPhoto> forPose(PhotoPose pose) =>
      _photos.where((p) => p.pose == pose).toList(growable: false);

  /// The two most recent captures of a pose (oldest, newest) — used by
  /// §46 comparison. Returns null when fewer than 2 exist.
  (ProgressPhoto, ProgressPhoto)? comparisonPair(PhotoPose pose) {
    final l = forPose(pose);
    if (l.length < 2) return null;
    return (l.first, l.last);
  }

  void add(ProgressPhoto photo) {
    _photos.add(photo);
    _photos.sort((a, b) => a.date.compareTo(b.date));
  }

  /// Delete record + return the file name so the caller can remove the
  /// image from disk atomically with the state change (§60 erasure).
  String? remove(String id) {
    final i = _photos.indexWhere((p) => p.id == id);
    if (i < 0) return null;
    return _photos.removeAt(i).fileName;
  }

  Map<String, dynamic> toJson() => {
        'photos': [for (final p in _photos) p.toJson()],
      };

  void hydrate(Map<String, dynamic>? json) {
    if (json == null) return;
    final list = json['photos'];
    if (list is! List) return;
    replaceWith(list);
  }

  /// Full replace — callers use `replaceWith([])` for §60 erasure.
  void replaceWith(List list) {
    _photos.clear();
    for (final e in list.whereType<Map>()) {
      final p = ProgressPhoto.fromJson(e);
      if (p != null) _photos.add(p);
    }
    _photos.sort((a, b) => a.date.compareTo(b.date));
  }

  /// §60 erasure: forget every photo record (image files are removed by
  /// the storage layer alongside this call).
  void eraseAll() => _photos.clear();
}
