import 'dart:math' as math;
import 'dart:ui' show Size;

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

  static const MorphRectNormV2 zero = MorphRectNormV2(
    x: 0.0,
    y: 0.0,
    w: 0.0,
    h: 0.0,
  );

  bool get isFiniteAndNonNegativeSize {
    return x.isFinite &&
        y.isFinite &&
        w.isFinite &&
        h.isFinite &&
        w >= 0.0 &&
        h >= 0.0;
  }

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

  int get pairCount => math.min(pairs.length, MorphProtocolV2Constants.maxPairs);

  List<MorphRectNormV2> get sourceRectsFixed8 =>
      _buildFixedRects((pair) => pair.source);

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

class MorphProtocolV2Constants {
  static const int maxPairs = 8;
  static const int scalarFloatCount = 5;
  static const int rectFloatCountPerSide = 32;
  static const int totalFloatCount = 69;
}
