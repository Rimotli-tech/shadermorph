import 'dart:ui' as ui;

import 'adapter.dart';
import 'coordinator.dart';

class MorphEngine {
  MorphEngine._(this._program);

  static const String shaderAssetKey =
      'packages/shadermorph_flutter/assets/shaders/core/morph_engine.frag';

  final ui.FragmentProgram _program;

  static Future<MorphEngine> load() async {
    final program = await ui.FragmentProgram.fromAsset(shaderAssetKey);
    return MorphEngine._(program);
  }

  ui.FragmentShader createShader({
    required ui.Size resolutionPx,
    required double progress,
    required int morphStyle,
    required double debugMode,
    required double texFlipY,
    required MorphMetadata metadata,
    required ui.Image texFrom,
    required ui.Image texTo,
  }) {
    final shader = _program.fragmentShader();
    MorphShaderAdapter.bind(
      shader,
      resolutionPx: resolutionPx,
      progress: progress,
      pairCount: metadata.pairCount,
      morphStyle: morphStyle,
      sourceRects: metadata.sourceRects,
      targetRects: metadata.targetRects,
      texFrom: texFrom,
      texTo: texTo,
      debugMode: debugMode,
      texFlipY: texFlipY,
    );
    return shader;
  }
}
