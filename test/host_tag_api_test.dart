import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadermorph_flutter/shadermorph_flutter.dart';

void main() {
  testWidgets('ShaderMorphHost.of throws with no host ancestor', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('no-host'))),
    );
    final context = tester.element(find.text('no-host'));
    expect(() => ShaderMorphHost.of(context), throwsFlutterError);
  });

  testWidgets('forwardByTag returns false when pair is incomplete', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ShaderMorphHost(
          child: Builder(
            builder: (context) {
              final host = ShaderMorphHost.of(context);
              return Scaffold(
                body: Column(
                  children: [
                    ShaderMorphTag(
                      id: 'x',
                      role: ShaderMorphRole.source,
                      child: const Text('source'),
                    ),
                    ElevatedButton(
                      onPressed: () => host.forwardByTag('x'),
                      child: const Text('go'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    final context = tester.element(find.text('go'));
    final host = ShaderMorphHost.of(context);
    final started = await host.forwardByTag('x');
    expect(started, isFalse);
  });

  testWidgets('forwardByTag returns false on duplicate mounted source tags', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ShaderMorphHost(
          child: Scaffold(
            body: Column(
              children: const [
                ShaderMorphTag(
                  id: 'dup',
                  role: ShaderMorphRole.source,
                  child: Text('source-a'),
                ),
                ShaderMorphTag(
                  id: 'dup',
                  role: ShaderMorphRole.source,
                  child: Text('source-b'),
                ),
                ShaderMorphTag(
                  id: 'dup',
                  role: ShaderMorphRole.destination,
                  child: Text('destination'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final context = tester.element(find.text('destination'));
    final started = await ShaderMorphHost.of(context).forwardByTag('dup');
    expect(started, isFalse);
  });

  testWidgets('tag-level trigger can invoke host methods', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ShaderMorphHost(
          child: Scaffold(
            body: Column(
              children: const [
                ShaderMorphTag(
                  id: 't',
                  role: ShaderMorphRole.source,
                  trigger: ShaderMorphTrigger.onTapForward,
                  child: Text('tap-source'),
                ),
                ShaderMorphTag(
                  id: 't',
                  role: ShaderMorphRole.destination,
                  child: Text('dest'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('tap-source'));
    await tester.pump();
    expect(find.text('tap-source'), findsOneWidget);
    expect(find.text('dest'), findsOneWidget);
  });
}
