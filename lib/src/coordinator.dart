import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'models.dart';
import 'metadata.dart';
import 'shape.dart';
import 'tracker.dart';

class MorphCoordinator {
  static const int _sourceBase = MorphProtocolConstants.scalarFloatCount;
  static const int _targetBase =
      _sourceBase + MorphProtocolConstants.rectFloatCountPerSide;
  static const int _sourceShapeBase =
      _targetBase + MorphProtocolConstants.rectFloatCountPerSide;
  static const int _targetShapeBase =
      _sourceShapeBase + MorphProtocolConstants.shapeFloatCountPerSide;

  static List<double> packUniformFloats({
    required MorphFrameMetadata metadata,
  }) {
    final packed = List<double>.filled(
      MorphProtocolConstants.totalFloatCount,
      0.0,
      growable: false,
    );

    packed[0] = metadata.resolutionPx.width;
    packed[1] = metadata.resolutionPx.height;
    packed[2] = metadata.progress;
    packed[3] = metadata.pairCount.toDouble();
    packed[4] = metadata.morphStyle.toDouble();

    final sources = metadata.sourceRectsFixed8;
    final targets = metadata.targetRectsFixed8;
    final sourceShapes = metadata.sourceShapesFixed8;
    final targetShapes = metadata.targetShapesFixed8;

    for (var i = 0; i < MorphProtocolConstants.maxPairs; i += 1) {
      final sourceOffset = _sourceBase + (i * 4);
      final source = sources[i];
      packed[sourceOffset] = source.x;
      packed[sourceOffset + 1] = source.y;
      packed[sourceOffset + 2] = source.w;
      packed[sourceOffset + 3] = source.h;

      final targetOffset = _targetBase + (i * 4);
      final target = targets[i];
      packed[targetOffset] = target.x;
      packed[targetOffset + 1] = target.y;
      packed[targetOffset + 2] = target.w;
      packed[targetOffset + 3] = target.h;

      final sourceShapeOffset = _sourceShapeBase + (i * 4);
      final sourceShape = sourceShapes[i];
      packed[sourceShapeOffset] = sourceShape.type;
      packed[sourceShapeOffset + 1] = sourceShape.radiusRatio;
      packed[sourceShapeOffset + 2] = sourceShape.reserved0;
      packed[sourceShapeOffset + 3] = sourceShape.reserved1;

      final targetShapeOffset = _targetShapeBase + (i * 4);
      final targetShape = targetShapes[i];
      packed[targetShapeOffset] = targetShape.type;
      packed[targetShapeOffset + 1] = targetShape.radiusRatio;
      packed[targetShapeOffset + 2] = targetShape.reserved0;
      packed[targetShapeOffset + 3] = targetShape.reserved1;
    }

    return List<double>.unmodifiable(packed);
  }

  static void setUniforms({
    required ui.FragmentShader shader,
    required MorphFrameMetadata metadata,
  }) {
    final packed = packUniformFloats(metadata: metadata);
    for (var i = 0; i < packed.length; i += 1) {
      shader.setFloat(i, packed[i]);
    }
  }

  static MorphFrameMetadata buildSinglePairMetadata({
    required Size logicalViewport,
    required MorphSnapshot sourceRect,
    required MorphSnapshot targetRect,
    required double progress,
    int morphStyle = 0,
    MorphShape sourceShape = const MorphShape.rect(),
    MorphShape targetShape = const MorphShape.rect(),
    bool clampRectsToUnit = false,
    bool usePhysicalResolution = true,
  }) {
    final dpr = sourceRect.pixelRatio;
    final sourceNorm = MorphTracker.normalizeLogicalRect(
      logicalRect: sourceRect.rect,
      logicalResolution: logicalViewport,
      devicePixelRatio: dpr,
      clampToUnit: clampRectsToUnit,
    );
    final targetNorm = MorphTracker.normalizeLogicalRect(
      logicalRect: targetRect.rect,
      logicalResolution: logicalViewport,
      devicePixelRatio: dpr,
      clampToUnit: clampRectsToUnit,
    );

    final resolution = usePhysicalResolution
        ? MorphTracker.logicalSizeToPhysicalSize(
            logicalSize: logicalViewport,
            devicePixelRatio: dpr,
          )
        : logicalViewport;

    return MorphFrameMetadata(
      resolutionPx: resolution,
      progress: progress,
      morphStyle: morphStyle,
      pairs: <MorphPairRects>[
        MorphPairRects(
          source: sourceNorm,
          target: targetNorm,
          sourceShape: MorphShapeData.fromShape(
            shape: sourceShape,
            logicalRect: sourceRect.rect,
          ),
          targetShape: MorphShapeData.fromShape(
            shape: targetShape,
            logicalRect: targetRect.rect,
          ),
        ),
      ],
    );
  }
}
