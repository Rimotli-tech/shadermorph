import 'package:flutter_test/flutter_test.dart';
import 'package:shadermorph_flutter/shadermorph_flutter.dart';

void main() {
  test('paper rip shader asset key is exposed', () {
    expect(
      MorphPaperRipTransition.shaderAssetKey,
      contains('morph_paper_rip.frag'),
    );
  });

  test('frosted glass shader asset key is exposed', () {
    expect(
      MorphFrostedGlassTransition.shaderAssetKey,
      contains('morph_frosted_glass.frag'),
    );
  });
}