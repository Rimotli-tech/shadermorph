import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shader texture sampling keeps Flutter top-left orientation', () {
    final shaderFiles = <String>[
      'shaders/shader_engine.frag',
      'shaders/shader_engine_shape_aware.frag',
    ];

    for (final path in shaderFiles) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        isNot(contains(RegExp(r'texture\s*\([^;]*1\.0\s*-\s*[^;]*\.y'))),
        reason: '$path must not invert sampler Y coordinates.',
      );
    }
  });
}
