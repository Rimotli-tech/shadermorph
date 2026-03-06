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
                      role: ShaderMorphRole.origin,
                      child: const Text('origin'),
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

  testWidgets('forwardByTag returns false on duplicate mounted origin tags', (
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
                  role: ShaderMorphRole.origin,
                  child: Text('origin-a'),
                ),
                ShaderMorphTag(
                  id: 'dup',
                  role: ShaderMorphRole.origin,
                  child: Text('origin-b'),
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
                  role: ShaderMorphRole.origin,
                  trigger: ShaderMorphTrigger.onTapForward,
                  child: Text('tap-origin'),
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

    await tester.tap(find.text('tap-origin'));
    await tester.pump();
    expect(find.text('tap-origin'), findsOneWidget);
    expect(find.text('dest'), findsOneWidget);
  });
}
