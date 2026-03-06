import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadermorph_flutter/shadermorph_flutter.dart';

void main() {
  testWidgets('ShaderMorphHost can be mounted with tag endpoints', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ShaderMorphHost(
          child: Scaffold(
            body: Column(
              children: [
                ShaderMorphTag(
                  id: 'a',
                  role: ShaderMorphRole.origin,
                  child: Text('origin'),
                ),
                ShaderMorphTag(
                  id: 'a',
                  role: ShaderMorphRole.destination,
                  child: Text('destination'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ShaderMorphHost), findsOneWidget);
    expect(find.byType(ShaderMorphTag), findsNWidgets(2));
  });

  testWidgets('ShaderMorph.tag returns cross-route tag widget', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShaderMorph.tag(id: 'tag1', child: const Text('tagged')),
        ),
      ),
    );

    expect(find.text('tagged'), findsOneWidget);
    final tag = tester.widget<CrossRouteMorphTag>(
      find.byType(CrossRouteMorphTag),
    );
    expect(tag.shadowCapturePolicy, MorphShadowCapturePolicy.exclude);
  });

  testWidgets('ShaderMorph.push returns false when no tagged origin exists', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(onPressed: () {}, child: const Text('go')),
          ),
        ),
      ),
    );

    final context = tester.element(find.text('go'));
    final started = await ShaderMorph.push(
      context: context,
      tagId: 'missing_tag',
      page: const Scaffold(body: Text('dest')),
    );
    expect(started, isFalse);

    final startedInclude = await ShaderMorph.push(
      context: context,
      tagId: 'missing_tag',
      page: const Scaffold(body: Text('dest2')),
      shadowCapturePolicy: MorphShadowCapturePolicy.include,
    );
    expect(startedInclude, isFalse);
  });
}
