import 'dart:math' as math;
import 'dart:ui' show Size;

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
  final String? id;

  const MorphPairRectsV2({
    required this.source,
    required this.target,
    this.id,
  });
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
  int get pairCount => math.min(pairs.length, MorphProtocolV2Constants.maxPairs);

  /// Fixed-size source rect array used by the packed shader contract.
  List<MorphRectNormV2> get sourceRectsFixed8 =>
      _buildFixedRects((pair) => pair.source);

  /// Fixed-size target rect array used by the packed shader contract.
  List<MorphRectNormV2> get targetRectsFixed8 =>
      _buildFixedRects((pair) => pair.target);

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
}

/// Constants for the deterministic Protocol-V2 float layout.
class MorphProtocolV2Constants {
  static const int maxPairs = 8;
  static const int scalarFloatCount = 5;
  static const int rectFloatCountPerSide = 32;
  static const int totalFloatCount = 69;
}
