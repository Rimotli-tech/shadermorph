import 'package:flutter_test/flutter_test.dart';
import 'package:shadermorph_flutter/src/transition_config.dart';

void main() {
  test('defaults are linear + classic', () {
    const config = MorphTransitionConfig();
    expect(config.interpolation, MorphInterpolation.linear);
    expect(config.shaderStyle, MorphShaderStyle.classic);
    expect(config.shaderStyleIndex, 0);
    expect(config.transformProgress(0.25), 0.25);
  });

  test('style index mapping is stable', () {
    expect(
      const MorphTransitionConfig(
        shaderStyle: MorphShaderStyle.classic,
      ).shaderStyleIndex,
      0,
    );
    expect(
      const MorphTransitionConfig(
        shaderStyle: MorphShaderStyle.soft,
      ).shaderStyleIndex,
      1,
    );
    expect(
      const MorphTransitionConfig(
        shaderStyle: MorphShaderStyle.ripple,
      ).shaderStyleIndex,
      2,
    );
    expect(
      const MorphTransitionConfig(
        shaderStyle: MorphShaderStyle.liquid,
      ).shaderStyleIndex,
      3,
    );
  });

  test('interpolation transforms progress deterministically', () {
    const inCfg = MorphTransitionConfig(
      interpolation: MorphInterpolation.easeIn,
    );
    const outCfg = MorphTransitionConfig(
      interpolation: MorphInterpolation.easeOut,
    );
    const inOutCfg = MorphTransitionConfig(
      interpolation: MorphInterpolation.easeInOut,
    );
    const smoothCfg = MorphTransitionConfig(
      interpolation: MorphInterpolation.smoothStep,
    );

    expect(inCfg.transformProgress(0.5), closeTo(0.125, 1e-9));
    expect(outCfg.transformProgress(0.5), closeTo(0.875, 1e-9));
    expect(inOutCfg.transformProgress(0.25), closeTo(0.0625, 1e-9));
    expect(inOutCfg.transformProgress(0.75), closeTo(0.9375, 1e-9));
    expect(smoothCfg.transformProgress(0.5), closeTo(0.5, 1e-9));
  });

  test('progress is clamped to [0, 1] before transform', () {
    const config = MorphTransitionConfig(
      interpolation: MorphInterpolation.easeIn,
    );
    expect(config.transformProgress(-5.0), 0.0);
    expect(config.transformProgress(5.0), 1.0);
  });
}
