import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadermorph_flutter/shadermorph_flutter.dart';

void main() {
  testWidgets('example-style ShaderMorphTag pushTo can mount', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShaderMorphTag(
            id: 'example_route',
            role: ShaderMorphRole.origin,
            pushTo: const Scaffold(body: Center(child: Text('Destination'))),
            policy: const ShaderMorphPolicy.disabled(),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    expect(find.text('Open'), findsOneWidget);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Destination'), findsOneWidget);
  });
}
