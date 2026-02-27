import 'dart:ui' as ui;

abstract class ShaderTransition {
  ui.FragmentShader createShader({
    required double uProgress,
    required ui.Size uResolution,
    required double uTime,
    required ui.Image uTexture0,
    required ui.Image uTexture1,
  });

  void configureShader(
    ui.FragmentShader shader, {
    required double uProgress,
    required ui.Size uResolution,
    required double uTime,
    required ui.Image uTexture0,
    required ui.Image uTexture1,
  });
}