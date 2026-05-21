import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

import 'shape.dart';

/// A normalized rect packed for Morph protocol shader uniforms.
class MorphRectNorm {
  final double x;
  final double y;
  final double w;
  final double h;

  const MorphRectNorm({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  /// A zero rect used for fixed-size uniform padding.
  static const MorphRectNorm zero = MorphRectNorm(
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
  MorphRectNorm clampedToUnit() {
    return MorphRectNorm(
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
    return other is MorphRectNorm &&
        other.x == x &&
        other.y == y &&
        other.w == w &&
        other.h == h;
  }

  @override
  int get hashCode => Object.hash(x, y, w, h);
}

/// A source/target pair prepared for Morph protocol packing.
class MorphPairRects {
  final MorphRectNorm source;
  final MorphRectNorm target;
  final MorphShapeData sourceShape;
  final MorphShapeData targetShape;
  final String? id;

  const MorphPairRects({
    required this.source,
    required this.target,
    this.sourceShape = MorphShapeData.rect,
    this.targetShape = MorphShapeData.rect,
    this.id,
  });
}

/// Packed structural shape metadata for a Morph protocol endpoint.
class MorphShapeData {
  final double type;
  final double radiusRatio;
  final double reserved0;
  final double reserved1;

  const MorphShapeData({
    required this.type,
    required this.radiusRatio,
    this.reserved0 = 0.0,
    this.reserved1 = 0.0,
  });

  static const MorphShapeData rect = MorphShapeData(
    type: 0.0,
    radiusRatio: 0.0,
  );

  factory MorphShapeData.fromShape({
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

    return MorphShapeData(
      type: shape.shaderType.toDouble(),
      radiusRatio: radiusRatio,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MorphShapeData &&
        other.type == type &&
        other.radiusRatio == radiusRatio &&
        other.reserved0 == reserved0 &&
        other.reserved1 == reserved1;
  }

  @override
  int get hashCode => Object.hash(type, radiusRatio, reserved0, reserved1);
}

/// Frame metadata packed into the Morph protocol uniform layout.
class MorphFrameMetadata {
  final Size resolutionPx;
  final double progress;
  final int morphStyle;
  final List<MorphPairRects> pairs;

  const MorphFrameMetadata({
    required this.resolutionPx,
    required this.progress,
    required this.morphStyle,
    required this.pairs,
  });

  /// Number of active pairs, capped to [MorphProtocolConstants.maxPairs].
  int get pairCount => math.min(pairs.length, MorphProtocolConstants.maxPairs);

  /// Pairs in deterministic protocol packing order.
  ///
  /// Named pairs are sorted lexicographically by id before truncation. Unnamed
  /// pairs are kept after named pairs in their caller-provided order, which
  /// preserves single-pair and synthetic test metadata that has no tag id.
  List<MorphPairRects> get pairsForPacking {
    final indexed = List<_IndexedMorphPair>.generate(
      pairs.length,
      (index) => _IndexedMorphPair(index: index, pair: pairs[index]),
      growable: false,
    );
    indexed.sort((a, b) {
      final aId = a.pair.id;
      final bId = b.pair.id;
      if (aId == null && bId == null) {
        return a.index.compareTo(b.index);
      }
      if (aId == null) return 1;
      if (bId == null) return -1;
      final byId = aId.compareTo(bId);
      return byId == 0 ? a.index.compareTo(b.index) : byId;
    });
    return List<MorphPairRects>.unmodifiable(
      indexed.map((entry) => entry.pair),
    );
  }

  /// Fixed-size source rect array used by the packed shader contract.
  List<MorphRectNorm> get sourceRectsFixed8 =>
      _buildFixedRects((pair) => pair.source);

  /// Fixed-size target rect array used by the packed shader contract.
  List<MorphRectNorm> get targetRectsFixed8 =>
      _buildFixedRects((pair) => pair.target);

  /// Fixed-size source shape array used by shape-aware shader styles.
  List<MorphShapeData> get sourceShapesFixed8 =>
      _buildFixedShapes((pair) => pair.sourceShape);

  /// Fixed-size target shape array used by shape-aware shader styles.
  List<MorphShapeData> get targetShapesFixed8 =>
      _buildFixedShapes((pair) => pair.targetShape);

  List<MorphRectNorm> _buildFixedRects(
    MorphRectNorm Function(MorphPairRects pair) selector,
  ) {
    final fixed = List<MorphRectNorm>.filled(
      MorphProtocolConstants.maxPairs,
      MorphRectNorm.zero,
      growable: false,
    );
    final capped = pairCount;
    final orderedPairs = pairsForPacking;
    for (var i = 0; i < capped; i += 1) {
      fixed[i] = selector(orderedPairs[i]);
    }
    return List<MorphRectNorm>.unmodifiable(fixed);
  }

  List<MorphShapeData> _buildFixedShapes(
    MorphShapeData Function(MorphPairRects pair) selector,
  ) {
    final fixed = List<MorphShapeData>.filled(
      MorphProtocolConstants.maxPairs,
      MorphShapeData.rect,
      growable: false,
    );
    final capped = pairCount;
    final orderedPairs = pairsForPacking;
    for (var i = 0; i < capped; i += 1) {
      fixed[i] = selector(orderedPairs[i]);
    }
    return List<MorphShapeData>.unmodifiable(fixed);
  }
}

class _IndexedMorphPair {
  final int index;
  final MorphPairRects pair;

  const _IndexedMorphPair({required this.index, required this.pair});
}

/// Constants for the deterministic Morph protocol float layout.
class MorphProtocolConstants {
  static const int maxPairs = 8;
  static const int scalarFloatCount = 5;
  static const int rectFloatCountPerSide = 32;
  static const int shapeFloatCountPerSide = 32;
  static const int totalFloatCount = 133;
}
