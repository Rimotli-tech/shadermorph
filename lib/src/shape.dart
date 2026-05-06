/// Structural shape metadata used by shape-aware morph styles.
enum MorphShapeKind { rect, roundedRect, circle, stadium }

/// Describes the intended silhouette of a morph endpoint.
class MorphShape {
  final MorphShapeKind kind;
  final double radius;

  const MorphShape._({required this.kind, this.radius = 0.0});

  /// A rectangular endpoint with square corners.
  const MorphShape.rect() : this._(kind: MorphShapeKind.rect);

  /// A rounded rectangle endpoint.
  const MorphShape.roundedRect({required double radius})
    : this._(kind: MorphShapeKind.roundedRect, radius: radius);

  /// A circular endpoint.
  const MorphShape.circle() : this._(kind: MorphShapeKind.circle);

  /// A stadium/capsule endpoint.
  const MorphShape.stadium() : this._(kind: MorphShapeKind.stadium);

  int get shaderType {
    switch (kind) {
      case MorphShapeKind.rect:
        return 0;
      case MorphShapeKind.roundedRect:
        return 1;
      case MorphShapeKind.circle:
        return 2;
      case MorphShapeKind.stadium:
        return 3;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MorphShape && other.kind == kind && other.radius == radius;
  }

  @override
  int get hashCode => Object.hash(kind, radius);
}
