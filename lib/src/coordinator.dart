import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'models.dart';
import 'models_v2.dart';
import 'tracker.dart';

class MorphCoordinator {
  static const int _v2SourceBase = MorphProtocolV2Constants.scalarFloatCount;
  static const int _v2TargetBase =
      _v2SourceBase + MorphProtocolV2Constants.rectFloatCountPerSide;

  static void setUniforms({
    required ui.FragmentShader shader,
    required Size viewport,
    required MorphSnapshot sourceRect,
    required MorphSnapshot targetRect,
    required double time,
    required double progress,
  }) {
    // Viewport Size
    shader.setFloat(0, viewport.width);
    shader.setFloat(1, viewport.height);

    // Global Coordinates (Exact match to tracker)
    shader.setFloat(2, sourceRect.rect.left);
    shader.setFloat(3, sourceRect.rect.top);
    shader.setFloat(4, sourceRect.rect.width);
    shader.setFloat(5, sourceRect.rect.height);

    shader.setFloat(6, targetRect.rect.left);
    shader.setFloat(7, targetRect.rect.top);
    shader.setFloat(8, targetRect.rect.width);
    shader.setFloat(9, targetRect.rect.height);

    shader.setFloat(10, time);
    shader.setFloat(11, progress);

    shader.setImageSampler(0, sourceRect.image);
    shader.setImageSampler(1, targetRect.image);
  }

  static List<double> packV2UniformFloats({
    required MorphFrameMetadataV2 metadata,
  }) {
    final packed = List<double>.filled(
      MorphProtocolV2Constants.totalFloatCount,
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

    for (var i = 0; i < MorphProtocolV2Constants.maxPairs; i += 1) {
      final sourceOffset = _v2SourceBase + (i * 4);
      final source = sources[i];
      packed[sourceOffset] = source.x;
      packed[sourceOffset + 1] = source.y;
      packed[sourceOffset + 2] = source.w;
      packed[sourceOffset + 3] = source.h;

      final targetOffset = _v2TargetBase + (i * 4);
      final target = targets[i];
      packed[targetOffset] = target.x;
      packed[targetOffset + 1] = target.y;
      packed[targetOffset + 2] = target.w;
      packed[targetOffset + 3] = target.h;
    }

    return List<double>.unmodifiable(packed);
  }

  static void setUniformsV2Packed({
    required ui.FragmentShader shader,
    required MorphFrameMetadataV2 metadata,
  }) {
    final packed = packV2UniformFloats(metadata: metadata);
    for (var i = 0; i < packed.length; i += 1) {
      shader.setFloat(i, packed[i]);
    }
  }

  static MorphFrameMetadataV2 buildSinglePairMetadataV2({
    required Size logicalViewport,
    required MorphSnapshot sourceRect,
    required MorphSnapshot targetRect,
    required double progress,
    int morphStyle = 0,
    bool clampRectsToUnit = false,
    bool usePhysicalResolution = true,
  }) {
    final dpr = sourceRect.pixelRatio;
    final sourceNorm = MorphTracker.normalizeLogicalRectToV2(
      logicalRect: sourceRect.rect,
      logicalResolution: logicalViewport,
      devicePixelRatio: dpr,
      clampToUnit: clampRectsToUnit,
    );
    final targetNorm = MorphTracker.normalizeLogicalRectToV2(
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

    return MorphFrameMetadataV2(
      resolutionPx: resolution,
      progress: progress,
      morphStyle: morphStyle,
      pairs: <MorphPairRectsV2>[
        MorphPairRectsV2(source: sourceNorm, target: targetNorm),
      ],
    );
  }
}
