import 'dart:ui' as ui;

import 'coordinator.dart';

class MorphShaderAdapter {
  const MorphShaderAdapter._();

  static const int maxPairs = 8;
  static const int scalarCount = 5;
  static const int sourceStart = scalarCount;
  static const int targetStart = sourceStart + (maxPairs * 4);
  static const int totalFloatCount = targetStart + (maxPairs * 4);
  static const int debugModeIndex = 69;

  static void bind(
    ui.FragmentShader shader, {
    required ui.Size resolutionPx,
    required double progress,
    required int pairCount,
    required int morphStyle,
    required List<MorphRect> sourceRects,
    required List<MorphRect> targetRects,
    required ui.Image texFrom,
    required ui.Image texTo,
    required double debugMode,
  }) {
    shader.setFloat(0, resolutionPx.width);
    shader.setFloat(1, resolutionPx.height);
    shader.setFloat(2, progress);
    shader.setFloat(3, pairCount.toDouble());
    shader.setFloat(4, morphStyle.toDouble());

    for (int i = 0; i < maxPairs; i++) {
      final sourceBase = sourceStart + (i * 4);
      final targetBase = targetStart + (i * 4);
      final s = sourceRects[i];
      final t = targetRects[i];

      shader.setFloat(sourceBase + 0, s.x);
      shader.setFloat(sourceBase + 1, s.y);
      shader.setFloat(sourceBase + 2, s.width);
      shader.setFloat(sourceBase + 3, s.height);

      shader.setFloat(targetBase + 0, t.x);
      shader.setFloat(targetBase + 1, t.y);
      shader.setFloat(targetBase + 2, t.width);
      shader.setFloat(targetBase + 3, t.height);
    }

    shader.setFloat(debugModeIndex, debugMode);

    shader.setImageSampler(0, texFrom);
    shader.setImageSampler(1, texTo);
  }
}
