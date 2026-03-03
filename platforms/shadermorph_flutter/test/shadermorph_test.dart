import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadermorph_flutter/shadermorph_flutter.dart';

class _FakePlaybackDelegate implements ShaderMorphPlaybackDelegate {
  final List<MorphDirection> calls = <MorphDirection>[];
  final bool returnValue;

  _FakePlaybackDelegate({required this.returnValue});

  @override
  Future<bool> play({required MorphDirection direction}) async {
    calls.add(direction);
    return returnValue;
  }
}

void main() {
  test('controller returns false when detached', () async {
    final controller = ShaderMorphController();
    expect(await controller.forward(), isFalse);
    expect(await controller.reverse(), isFalse);
  });

  test('controller delegates directional calls', () async {
    final controller = ShaderMorphController();
    final delegate = _FakePlaybackDelegate(returnValue: true);
    controller.attach(delegate);

    expect(await controller.forward(), isTrue);
    expect(await controller.reverse(), isTrue);
    expect(delegate.calls, <MorphDirection>[
      MorphDirection.forward,
      MorphDirection.reverse,
    ]);
  });

  test('waitForState resolves when target state is reached', () async {
    final controller = ShaderMorphController();
    final future = controller.waitForState(
      MorphPlaybackState.idleDestination,
      timeout: const Duration(milliseconds: 100),
    );
    controller.debugSetState(MorphPlaybackState.idleDestination);
    expect(await future, isTrue);
  });

  testWidgets('ShaderMorph has no internal tap gesture trigger', (
    WidgetTester tester,
  ) async {
    final controller = ShaderMorphController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShaderMorph(
            controller: controller,
            source: const Text('source'),
            destination: const Text('destination'),
          ),
        ),
      ),
    );

    final gestureInMorph = find.descendant(
      of: find.byType(ShaderMorph),
      matching: find.byType(GestureDetector),
    );
    expect(gestureInMorph, findsNothing);
  });

  testWidgets('MorphTag registers and unregisters tag keys', (
    WidgetTester tester,
  ) async {
    MorphTagRegistry.instance.clearForTesting();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MorphTag(id: 'tag_a', child: Text('A')),
        ),
      ),
    );

    expect(MorphTagRegistry.instance.keyFor('tag_a'), isNotNull);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );

    expect(MorphTagRegistry.instance.keyFor('tag_a'), isNull);
  });

  testWidgets(
    'CrossRouteMorphController startToRoute returns false without tag',
    (WidgetTester tester) async {
      final controller = CrossRouteMorphController();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  await controller.startToRoute(
                    context: context,
                    tagId: 'missing_tag',
                    route: MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(body: Text('dest')),
                    ),
                  );
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      final started = await controller.startToRoute(
        context: tester.element(find.text('go')),
        tagId: 'missing_tag',
        route: MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('dest')),
        ),
      );
      expect(started, isFalse);
    },
  );
}
