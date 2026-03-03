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

  testWidgets('MorphTagRegistry keeps tag active when one duplicate unmounts', (
    WidgetTester tester,
  ) async {
    MorphTagRegistry.instance.clearForTesting();
    var showSecond = true;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: Column(
                children: [
                  const MorphTag(id: 'shared', child: Text('first')),
                  if (showSecond)
                    const MorphTag(id: 'shared', child: Text('second')),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        showSecond = false;
                      });
                    },
                    child: const Text('remove'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    final firstKey = MorphTagRegistry.instance.keyFor('shared');
    expect(firstKey, isNotNull);

    await tester.tap(find.text('remove'));
    await tester.pumpAndSettle();

    final remainingKey = MorphTagRegistry.instance.keyFor('shared');
    expect(remainingKey, isNotNull);
    expect(remainingKey, isNot(firstKey));
  });

  testWidgets('unregister does not clear hidden state for sibling duplicate', (
    WidgetTester tester,
  ) async {
    MorphTagRegistry.instance.clearForTesting();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MorphTag(id: 'shared_hidden', child: Text('A')),
              MorphTag(id: 'shared_hidden', child: Text('B')),
            ],
          ),
        ),
      ),
    );

    final latestKey = MorphTagRegistry.instance.keyFor('shared_hidden');
    expect(latestKey, isNotNull);
    final hiddenKey = MorphTagRegistry.instance.keyForExcluding(
      'shared_hidden',
      latestKey!,
    );
    expect(hiddenKey, isNotNull);
    MorphTagRegistry.instance.setHiddenForKey(hiddenKey!, hidden: true);
    await tester.pump();
    expect(MorphTagRegistry.instance.hiddenTags.value.contains(hiddenKey), isTrue);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MorphTag(id: 'shared_hidden', child: Text('A')),
        ),
      ),
    );
    await tester.pump();

    expect(MorphTagRegistry.instance.hiddenTags.value.contains(hiddenKey), isTrue);
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
