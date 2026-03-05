import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadermorph_flutter/shadermorph_flutter.dart';

void main() {
  testWidgets('CrossRouteMorphTag registers and unregisters tag keys', (
    WidgetTester tester,
  ) async {
    MorphTagRegistry.instance.clearForTesting();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CrossRouteMorphTag(id: 'tag_a', child: Text('A')),
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
                  const CrossRouteMorphTag(id: 'shared', child: Text('first')),
                  if (showSecond)
                    const CrossRouteMorphTag(
                      id: 'shared',
                      child: Text('second'),
                    ),
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
              CrossRouteMorphTag(id: 'shared_hidden', child: Text('A')),
              CrossRouteMorphTag(id: 'shared_hidden', child: Text('B')),
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
    expect(
      MorphTagRegistry.instance.hiddenTags.value.contains(hiddenKey),
      isTrue,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CrossRouteMorphTag(id: 'shared_hidden', child: Text('A')),
        ),
      ),
    );
    await tester.pump();

    expect(
      MorphTagRegistry.instance.hiddenTags.value.contains(hiddenKey),
      isTrue,
    );
  });

  testWidgets(
    'ShaderMorphCrossRouteEngine startToRoute returns false without tag',
    (WidgetTester tester) async {
      final engine = ShaderMorphCrossRouteEngine();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  await engine.startToRoute(
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

      final started = await engine.startToRoute(
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
