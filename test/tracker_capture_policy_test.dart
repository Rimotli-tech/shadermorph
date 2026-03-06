import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadermorph_flutter/src/models.dart';
import 'package:shadermorph_flutter/src/tracker.dart';

void main() {
  testWidgets(
    'exclude mode without dedicated capture child falls back to host',
    (WidgetTester tester) async {
      final hostKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShaderMorphCaptureLayer(
              boundaryKey: hostKey,
              shadowCapturePolicy: MorphShadowCapturePolicy.exclude,
              child: const Text('exclude'),
            ),
          ),
        ),
      );

      final mapped = MorphCaptureLayerRegistry.instance.captureKeyFor(hostKey);
      expect(mapped, isNull);
    },
  );

  testWidgets(
    'exclude mode with dedicated capture child registers capture key',
    (WidgetTester tester) async {
      final hostKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShaderMorphCaptureLayer(
              boundaryKey: hostKey,
              shadowCapturePolicy: MorphShadowCapturePolicy.exclude,
              captureChild: const Text('capture'),
              child: const Text('visible'),
            ),
          ),
        ),
      );

      final mapped = MorphCaptureLayerRegistry.instance.captureKeyFor(hostKey);
      expect(mapped, isNotNull);
      expect(mapped, isNot(hostKey));
    },
  );

  testWidgets('include mode does not register a dedicated capture key', (
    WidgetTester tester,
  ) async {
    final hostKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShaderMorphCaptureLayer(
            boundaryKey: hostKey,
            shadowCapturePolicy: MorphShadowCapturePolicy.include,
            child: const Text('include'),
          ),
        ),
      ),
    );

    final mapped = MorphCaptureLayerRegistry.instance.captureKeyFor(hostKey);
    expect(mapped, isNull);
  });

  testWidgets('registry mapping is removed when layer unmounts', (
    WidgetTester tester,
  ) async {
    final hostKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShaderMorphCaptureLayer(
            boundaryKey: hostKey,
            shadowCapturePolicy: MorphShadowCapturePolicy.exclude,
            captureChild: const Text('capture'),
            child: const Text('mounted'),
          ),
        ),
      ),
    );
    expect(
      MorphCaptureLayerRegistry.instance.captureKeyFor(hostKey),
      isNotNull,
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );

    expect(MorphCaptureLayerRegistry.instance.captureKeyFor(hostKey), isNull);
  });
}
