import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'models.dart';
import 'models_v2.dart';

class MorphTracker {
  static Rect logicalRectToPhysicalRect({
    required Rect logicalRect,
    required double devicePixelRatio,
  }) {
    return Rect.fromLTWH(
      logicalRect.left * devicePixelRatio,
      logicalRect.top * devicePixelRatio,
      logicalRect.width * devicePixelRatio,
      logicalRect.height * devicePixelRatio,
    );
  }

  static Size logicalSizeToPhysicalSize({
    required Size logicalSize,
    required double devicePixelRatio,
  }) {
    return Size(
      logicalSize.width * devicePixelRatio,
      logicalSize.height * devicePixelRatio,
    );
  }

  static MorphRectNormV2 normalizePhysicalRectToV2({
    required Rect physicalRect,
    required Size resolutionPx,
    bool clampToUnit = false,
  }) {
    if (!resolutionPx.width.isFinite ||
        !resolutionPx.height.isFinite ||
        resolutionPx.width <= 0.0 ||
        resolutionPx.height <= 0.0) {
      return MorphRectNormV2.zero;
    }

    final normalized = MorphRectNormV2(
      x: physicalRect.left / resolutionPx.width,
      y: physicalRect.top / resolutionPx.height,
      w: physicalRect.width / resolutionPx.width,
      h: physicalRect.height / resolutionPx.height,
    );

    if (!clampToUnit) {
      return normalized;
    }
    return normalized.clampedToUnit();
  }

  static MorphRectNormV2 normalizeLogicalRectToV2({
    required Rect logicalRect,
    required Size logicalResolution,
    required double devicePixelRatio,
    bool clampToUnit = false,
  }) {
    if (!devicePixelRatio.isFinite || devicePixelRatio <= 0.0) {
      return MorphRectNormV2.zero;
    }

    final physicalRect = logicalRectToPhysicalRect(
      logicalRect: logicalRect,
      devicePixelRatio: devicePixelRatio,
    );
    final physicalResolution = logicalSizeToPhysicalSize(
      logicalSize: logicalResolution,
      devicePixelRatio: devicePixelRatio,
    );

    return normalizePhysicalRectToV2(
      physicalRect: physicalRect,
      resolutionPx: physicalResolution,
      clampToUnit: clampToUnit,
    );
  }

  static Future<MorphSnapshot> capture(GlobalKey key) async {
    return _captureSingle(key);
  }

  static Future<MorphPairSnapshot> capturePair({
    required GlobalKey sourceKey,
    required GlobalKey destinationKey,
  }) async {
    final source = await _captureSingle(sourceKey);
    final destination = await _captureSingle(destinationKey);
    return MorphPairSnapshot(source: source, destination: destination);
  }

  static Future<MorphSnapshot> _captureSingle(GlobalKey key) async {
    final context = key.currentContext;
    if (context == null) throw Exception("MorphTracker: Context not found.");

    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) throw Exception("Could not find RenderBox");

    // Get Global Position
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final rect = Rect.fromLTWH(
      position.dx,
      position.dy,
      size.width,
      size.height,
    );

    // Get Pixels
    final boundary = renderBox as RenderRepaintBoundary;
    final pixelRatio = View.of(context).devicePixelRatio;
    final image = await boundary.toImage(pixelRatio: pixelRatio);

    return MorphSnapshot(image: image, rect: rect, pixelRatio: pixelRatio);
  }
}
