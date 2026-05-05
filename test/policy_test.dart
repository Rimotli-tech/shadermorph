import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadermorph_flutter/shadermorph_flutter.dart';

void main() {
  test('policy modes resolve animation allowance', () {
    expect(
      const ShaderMorphPolicy.always().allowsAnimationFor(isWeb: false),
      isTrue,
    );
    expect(
      const ShaderMorphPolicy.always().allowsAnimationFor(isWeb: true),
      isTrue,
    );
    expect(
      const ShaderMorphPolicy.disabled().allowsAnimationFor(isWeb: false),
      isFalse,
    );
    expect(
      const ShaderMorphPolicy.disabled().allowsAnimationFor(isWeb: true),
      isFalse,
    );
    expect(
      const ShaderMorphPolicy.disabledOnWeb().allowsAnimationFor(isWeb: false),
      isTrue,
    );
    expect(
      const ShaderMorphPolicy.disabledOnWeb().allowsAnimationFor(isWeb: true),
      isFalse,
    );
  });

  testWidgets('disabled host policy instant-settles to destination', (
    tester,
  ) async {
    var originTaps = 0;
    var destinationTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ShaderMorphHost(
          policy: const ShaderMorphPolicy.disabled(),
          child: Builder(
            builder: (context) {
              final host = ShaderMorphHost.of(context);
              return Scaffold(
                body: Column(
                  children: [
                    ShaderMorphTag(
                      id: 'instant',
                      role: ShaderMorphRole.origin,
                      child: GestureDetector(
                        onTap: () {
                          originTaps += 1;
                        },
                        child: const Text('origin endpoint'),
                      ),
                    ),
                    ShaderMorphTag(
                      id: 'instant',
                      role: ShaderMorphRole.destination,
                      child: GestureDetector(
                        onTap: () {
                          destinationTaps += 1;
                        },
                        child: const Text('destination endpoint'),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => host.forwardByTag('instant'),
                      child: const Text('forward'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('destination endpoint'), warnIfMissed: false);
    expect(destinationTaps, 0);

    final host = ShaderMorphHost.of(tester.element(find.text('forward')));
    final started = await host.forwardByTag('instant');
    await tester.pump();

    expect(started, isTrue);

    await tester.tap(find.text('origin endpoint'), warnIfMissed: false);
    await tester.tap(find.text('destination endpoint'));

    expect(originTaps, 0);
    expect(destinationTaps, 1);
  });

  testWidgets('disabled cross-route policy pushes and pops without engine', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(onPressed: () {}, child: const Text('home')),
            );
          },
        ),
      ),
    );

    final homeContext = tester.element(find.text('home'));
    final started = await ShaderMorph.push(
      context: homeContext,
      tagId: 'no_engine',
      policy: const ShaderMorphPolicy.disabled(),
      page: const Scaffold(body: Center(child: Text('destination page'))),
    );

    expect(started, isTrue);
    await tester.pumpAndSettle();
    expect(find.text('destination page'), findsOneWidget);

    final destinationContext = tester.element(find.text('destination page'));
    final reversed = await ShaderMorph.reverseAndPop(
      destinationContext,
      tagId: 'no_engine',
    );
    await tester.pumpAndSettle();

    expect(reversed, isFalse);
    expect(find.text('home'), findsOneWidget);
  });
}
