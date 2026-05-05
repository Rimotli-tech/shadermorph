import 'package:flutter/foundation.dart';

/// Manual policy for allowing or suppressing ShaderMorph animations.
enum ShaderMorphPolicyMode { always, disabled, disabledOnWeb }

/// Controls whether ShaderMorph should animate or instant-settle.
class ShaderMorphPolicy {
  final ShaderMorphPolicyMode mode;

  const ShaderMorphPolicy._(this.mode);

  /// Always run ShaderMorph animations.
  const ShaderMorphPolicy.always() : this._(ShaderMorphPolicyMode.always);

  /// Never run ShaderMorph animations; instant-settle instead.
  const ShaderMorphPolicy.disabled() : this._(ShaderMorphPolicyMode.disabled);

  /// Suppress ShaderMorph animations on web only.
  const ShaderMorphPolicy.disabledOnWeb()
    : this._(ShaderMorphPolicyMode.disabledOnWeb);

  /// Returns whether animation is allowed in the current runtime.
  bool get allowsAnimation => allowsAnimationFor(isWeb: kIsWeb);

  @visibleForTesting
  bool allowsAnimationFor({required bool isWeb}) {
    switch (mode) {
      case ShaderMorphPolicyMode.always:
        return true;
      case ShaderMorphPolicyMode.disabled:
        return false;
      case ShaderMorphPolicyMode.disabledOnWeb:
        return !isWeb;
    }
  }
}
