import 'dart:ui' as ui;

import 'shader_transition.dart';

class MorphPaperRipTransition implements ShaderTransition {
  MorphPaperRipTransition._(this._program);

  static const String shaderAssetKey =
      'packages/shadermorph_flutter/assets/shaders/core/morph_paper_rip.frag';

  final ui.FragmentProgram _program;

  static Future<MorphPaperRipTransition> load() async {
    final program = await ui.FragmentProgram.fromAsset(shaderAssetKey);
    return MorphPaperRipTransition._(program);
  }

  @override
  ui.FragmentShader createShader({
    required double uProgress,
    required ui.Size uResolution,
    required double uTime,
    required ui.Image uTexture0,
    required ui.Image uTexture1,
  }) {
    final shader = _program.fragmentShader();
    configureShader(
      shader,
      uProgress: uProgress,
      uResolution: uResolution,
      uTime: uTime,
      uTexture0: uTexture0,
      uTexture1: uTexture1,
    );
    return shader;
  }

  @override
  void configureShader(
    ui.FragmentShader shader, {
    required double uProgress,
    required ui.Size uResolution,
    required double uTime,
    required ui.Image uTexture0,
    required ui.Image uTexture1,
  }) {
    // Uniform Contract V1 float order: u_progress, u_resolution.x, u_resolution.y, u_time
    shader.setFloat(0, uProgress);
    shader.setFloat(1, uResolution.width);
    shader.setFloat(2, uResolution.height);
    shader.setFloat(3, uTime);

    // Uniform Contract V1 sampler order: u_texture0, u_texture1
    shader.setImageSampler(0, uTexture0);
    shader.setImageSampler(1, uTexture1);
  }
}