import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadermorph_flutter/shadermorph_flutter.dart';

void main() {
  testWidgets('ShaderMorph can be used without explicitly passing a controller', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ShaderMorph(
            source: Text('source'),
            destination: Text('destination'),
          ),
        ),
      ),
    );

    expect(find.byType(ShaderMorph), findsOneWidget);
  });

  testWidgets('ShaderMorph.tag returns tag widget for cross-route endpoint', (
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
  });

  testWidgets('ShaderMorphHandle.of throws when no ShaderMorph ancestor', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('no morph'))),
    );

    final context = tester.element(find.text('no morph'));
    expect(() => ShaderMorphHandle.of(context), throwsFlutterError);
  });

  testWidgets('ShaderMorph.push returns false when no tagged source exists', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {},
              child: const Text('go'),
            ),
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
  });
}
