import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

import 'shape.dart';

/// A normalized rect packed for Protocol-V2 shader uniforms.
class MorphRectNormV2 {
  final double x;
  final double y;
  final double w;
  final double h;

  const MorphRectNormV2({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  /// A zero rect used for fixed-size uniform padding.
  static const MorphRectNormV2 zero = MorphRectNormV2(
    x: 0.0,
    y: 0.0,
    w: 0.0,
    h: 0.0,
  );

  /// Returns `true` when all coordinates are finite and the size is non-negative.
  bool get isFiniteAndNonNegativeSize {
    return x.isFinite &&
        y.isFinite &&
        w.isFinite &&
        h.isFinite &&
        w >= 0.0 &&
        h >= 0.0;
  }

  /// Clamps every field into the inclusive `[0, 1]` range.
  MorphRectNormV2 clampedToUnit() {
    return MorphRectNormV2(
      x: _clamp01(x),
      y: _clamp01(y),
      w: _clamp01(w),
      h: _clamp01(h),
    );
  }

  static double _clamp01(double value) => value.clamp(0.0, 1.0).toDouble();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MorphRectNormV2 &&
        other.x == x &&
        other.y == y &&
        other.w == w &&
        other.h == h;
  }

  @override
  int get hashCode => Object.hash(x, y, w, h);
}

/// A source/target pair prepared for Protocol-V2 packing.
class MorphPairRectsV2 {
  final MorphRectNormV2 source;
  final MorphRectNormV2 target;
  final MorphShapeDataV2 sourceShape;
  final MorphShapeDataV2 targetShape;
  final String? id;

  const MorphPairRectsV2({
    required this.source,
    required this.target,
    this.sourceShape = MorphShapeDataV2.rect,
    this.targetShape = MorphShapeDataV2.rect,
    this.id,
  });
}

/// Packed structural shape metadata for a Protocol-V2 endpoint.
class MorphShapeDataV2 {
  final double type;
  final double radiusRatio;
  final double reserved0;
  final double reserved1;

  const MorphShapeDataV2({
    required this.type,
    required this.radiusRatio,
    this.reserved0 = 0.0,
    this.reserved1 = 0.0,
  });

  static const MorphShapeDataV2 rect = MorphShapeDataV2(
    type: 0.0,
    radiusRatio: 0.0,
  );

  factory MorphShapeDataV2.fromShape({
    required MorphShape shape,
    required Rect logicalRect,
  }) {
    final minDimension = math.min(logicalRect.width, logicalRect.height);
    final safeMinDimension = minDimension.isFinite && minDimension > 0.0
        ? minDimension
        : 1.0;
    final radiusRatio = switch (shape.kind) {
      MorphShapeKind.rect => 0.0,
      MorphShapeKind.roundedRect =>
        (shape.radius / safeMinDimension).clamp(0.0, 0.5).toDouble(),
      MorphShapeKind.circle => 0.5,
      MorphShapeKind.stadium => 0.5,
    };

    return MorphShapeDataV2(
      type: shape.shaderType.toDouble(),
      radiusRatio: radiusRatio,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MorphShapeDataV2 &&
        other.type == type &&
        other.radiusRatio == radiusRatio &&
        other.reserved0 == reserved0 &&
        other.reserved1 == reserved1;
  }

  @override
  int get hashCode => Object.hash(type, radiusRatio, reserved0, reserved1);
}

/// Frame metadata packed into the Protocol-V2 uniform layout.
class MorphFrameMetadataV2 {
  final Size resolutionPx;
  final double progress;
  final int morphStyle;
  final List<MorphPairRectsV2> pairs;

  const MorphFrameMetadataV2({
    required this.resolutionPx,
    required this.progress,
    required this.morphStyle,
    required this.pairs,
  });

  /// Number of active pairs, capped to [MorphProtocolV2Constants.maxPairs].
  int get pairCount =>
      math.min(pairs.length, MorphProtocolV2Constants.maxPairs);

  /// Fixed-size source rect array used by the packed shader contract.
  List<MorphRectNormV2> get sourceRectsFixed8 =>
      _buildFixedRects((pair) => pair.source);

  /// Fixed-size target rect array used by the packed shader contract.
  List<MorphRectNormV2> get targetRectsFixed8 =>
      _buildFixedRects((pair) => pair.target);

  /// Fixed-size source shape array used by shape-aware shader styles.
  List<MorphShapeDataV2> get sourceShapesFixed8 =>
      _buildFixedShapes((pair) => pair.sourceShape);

  /// Fixed-size target shape array used by shape-aware shader styles.
  List<MorphShapeDataV2> get targetShapesFixed8 =>
      _buildFixedShapes((pair) => pair.targetShape);

  List<MorphRectNormV2> _buildFixedRects(
    MorphRectNormV2 Function(MorphPairRectsV2 pair) selector,
  ) {
    final fixed = List<MorphRectNormV2>.filled(
      MorphProtocolV2Constants.maxPairs,
      MorphRectNormV2.zero,
      growable: false,
    );
    final capped = pairCount;
    for (var i = 0; i < capped; i += 1) {
      fixed[i] = selector(pairs[i]);
    }
    return List<MorphRectNormV2>.unmodifiable(fixed);
  }

  List<MorphShapeDataV2> _buildFixedShapes(
    MorphShapeDataV2 Function(MorphPairRectsV2 pair) selector,
  ) {
    final fixed = List<MorphShapeDataV2>.filled(
      MorphProtocolV2Constants.maxPairs,
      MorphShapeDataV2.rect,
      growable: false,
    );
    final capped = pairCount;
    for (var i = 0; i < capped; i += 1) {
      fixed[i] = selector(pairs[i]);
    }
    return List<MorphShapeDataV2>.unmodifiable(fixed);
  }
}

/// Constants for the deterministic Protocol-V2 float layout.
class MorphProtocolV2Constants {
  static const int maxPairs = 8;
  static const int scalarFloatCount = 5;
  static const int rectFloatCountPerSide = 32;
  static const int shapeFloatCountPerSide = 32;
  static const int totalFloatCount = 133;
}
