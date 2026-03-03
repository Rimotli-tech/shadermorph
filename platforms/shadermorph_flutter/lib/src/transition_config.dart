enum MorphInterpolation {
  linear,
  easeIn,
  easeOut,
  easeInOut,
  smoothStep,
}

enum MorphShaderStyle {
  classic,
  soft,
  ripple,
}

class MorphTransitionConfig {
  final MorphInterpolation interpolation;
  final MorphShaderStyle shaderStyle;

  const MorphTransitionConfig({
    this.interpolation = MorphInterpolation.linear,
    this.shaderStyle = MorphShaderStyle.classic,
  });

  double transformProgress(double progress) {
    final t = progress.clamp(0.0, 1.0).toDouble();
    switch (interpolation) {
      case MorphInterpolation.linear:
        return t;
      case MorphInterpolation.easeIn:
        return t * t * t;
      case MorphInterpolation.easeOut:
        final inv = 1.0 - t;
        return 1.0 - (inv * inv * inv);
      case MorphInterpolation.easeInOut:
        if (t < 0.5) {
          return 4.0 * t * t * t;
        }
        final inv = -2.0 * t + 2.0;
        return 1.0 - ((inv * inv * inv) / 2.0);
      case MorphInterpolation.smoothStep:
        return t * t * (3.0 - (2.0 * t));
    }
  }

  int get shaderStyleIndex {
    switch (shaderStyle) {
      case MorphShaderStyle.classic:
        return 0;
      case MorphShaderStyle.soft:
        return 1;
      case MorphShaderStyle.ripple:
        return 2;
    }
  }
}
