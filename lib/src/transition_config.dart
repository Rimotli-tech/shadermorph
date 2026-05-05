/// Easing curves available for morph progress shaping.
enum MorphInterpolation { linear, easeIn, easeOut, easeInOut, smoothStep }

/// Public shader styles exposed by the package.
enum MorphShaderStyle { standard }

/// Runtime configuration shared by single-page and cross-route transitions.
class MorphTransitionConfig {
  final MorphInterpolation interpolation;
  final MorphShaderStyle shaderStyle;

  const MorphTransitionConfig({
    this.interpolation = MorphInterpolation.linear,
    this.shaderStyle = MorphShaderStyle.standard,
  });

  /// Applies the selected interpolation curve to a normalized progress value.
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

  /// Stable style slot expected by the current shader protocol.
  int get shaderStyleIndex {
    return 1;
  }
}
