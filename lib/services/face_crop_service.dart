import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/player.dart';

/// Lazily-initialized singleton wrapping `face_detection_tflite` to bias each
/// player photo's `BoxFit.cover` alignment toward their detected face,
/// instead of a fixed center crop. Verified against the installed package's
/// actual source (v6.5.0): `Face.detectionData.boundingBox` is already a
/// normalized (0..1) `RectF`, so no separate image-dimension decode is
/// needed to convert it into Flutter's `Alignment(-1..1)` space.
///
/// Detection never throws out of this service — a missing/corrupt photo
/// asset or any detector failure degrades to a neutral alignment rather than
/// aborting an export.
class FaceCropService {
  FaceCropService._();

  static final FaceCropService instance = FaceCropService._();

  // Cache the in-flight Future itself (not the resolved value) so concurrent
  // callers racing to create the detector all await the same Future instead
  // of each independently spawning its own isolate + reloading the models —
  // `_detector ??= await FaceDetector.create()` would be racy since the
  // null-check happens synchronously but the assignment only after the
  // `await` resolves.
  Future<FaceDetector>? _detectorFuture;
  final Map<String, Alignment> _cache = {};

  /// Fixed upper-center bias used when no face is detected — most headshot
  /// photos place the face in the upper portion of the frame.
  static const _fallbackAlignment = Alignment(0, -0.3);

  /// Returns a cached or freshly-computed [Alignment] biased toward
  /// [player]'s detected face, for use with `Image.asset(..., fit:
  /// BoxFit.cover, alignment: ...)`.
  Future<Alignment> alignmentFor(Player player) async {
    final key = player.photoFileName ?? player.getPlayerPhoto();
    final cached = _cache[key];
    if (cached != null) return cached;

    final alignment = await _computeAlignment(player);
    _cache[key] = alignment;
    return alignment;
  }

  /// Created once and kept alive for the app's session — memoizing the
  /// Future (not the value) means every concurrent caller awaits the same
  /// in-flight creation instead of each spawning its own isolate.
  Future<FaceDetector> _getDetector() => _detectorFuture ??= FaceDetector.create();

  Future<Alignment> _computeAlignment(Player player) async {
    try {
      final detector = await _getDetector();

      final data = await rootBundle.load(player.getPlayerPhoto());
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      // `fast` mode skips mesh/iris computation we don't need — bounding
      // box only, which is all this service uses.
      final faces = await detector.detectFacesFromBytes(
        bytes,
        mode: FaceDetectionMode.fast,
      );
      if (faces.isEmpty) return _fallbackAlignment;

      final largest = faces.reduce(
        (a, b) => _pixelArea(a) >= _pixelArea(b) ? a : b,
      );

      // Already normalized 0..1 — no image width/height needed.
      final box = largest.detectionData.boundingBox;
      final centerX = (box.xmin + box.xmax) / 2;
      final centerY = (box.ymin + box.ymax) / 2;
      return Alignment(
        (centerX * 2 - 1).clamp(-1.0, 1.0),
        (centerY * 2 - 1).clamp(-1.0, 1.0),
      );
    } catch (_) {
      return Alignment.center;
    }
  }

  /// Absolute-pixel bounding-box area, used to pick "the subject" when
  /// multiple faces are detected in one photo (e.g. a background photobomb).
  double _pixelArea(Face face) {
    final box = face.boundingBox;
    final width = box.topRight.x - box.topLeft.x;
    final height = box.bottomLeft.y - box.topLeft.y;
    return width * height;
  }
}
