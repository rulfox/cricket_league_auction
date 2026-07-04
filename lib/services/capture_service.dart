import 'dart:typed_data';
import 'dart:ui' show ImageByteFormat;

import 'package:archive/archive.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show GlobalKey;

/// Generalizes the app's original single-card `RepaintBoundary` capture
/// pattern so it can back single-card export, the all-players zip, and the
/// per-team card zip with one implementation.
///
/// Frame-timing (setState + precacheImage + waiting for the frame that
/// paints the new content) is necessarily the caller's responsibility via
/// [prepareFrame], since only the calling `State` can drive its own widget
/// tree/build cycle.
class CaptureService {
  const CaptureService({this.pixelRatio = 2.0});

  final double pixelRatio;

  Future<Uint8List> captureBoundary(GlobalKey boundaryKey) async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes =
        (await image.toByteData(format: ImageByteFormat.png))!.buffer.asUint8List();
    image.dispose();
    return bytes;
  }

  /// Captures one PNG per item and bundles them into a single (uncompressed
  /// — PNG is already compressed) zip archive, reporting progress as it goes.
  Future<Uint8List> captureSequenceAsZip<T>({
    required List<T> items,
    required GlobalKey boundaryKey,
    required Future<void> Function(T item) prepareFrame,
    required String Function(T item) fileNameFor,
    required void Function(int completed, int total) onProgress,
  }) async {
    final archive = Archive();
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      await prepareFrame(item);
      final bytes = await captureBoundary(boundaryKey);
      final file = ArchiveFile(fileNameFor(item), bytes.length, bytes)
        ..compress = false;
      archive.addFile(file);
      onProgress(i + 1, items.length);
    }
    final zip = ZipEncoder().encode(archive)!;
    return Uint8List.fromList(zip);
  }
}
