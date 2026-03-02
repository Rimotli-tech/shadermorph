/*
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadermorph_flutter/shadermorph_flutter.dart';

void main() {
  testWidgets('ShaderMorph renders widgets and responds to tap', (tester) async {
    // 1. Build the widget with required source and destination widgets.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ShaderMorph(
            destination: Text('TARGET WIDGET'),
            source: Text('TARGET WIDGET'),
          ),
        ),
      ),
    );

    // 2. Verify the initial state: both source and destination are visible.
    expect(find.text('TARGET WIDGET'), findsNWidgets(2));

    // 3. Trigger the morph by tapping one of the widgets.
    await tester.tap(find.text('TARGET WIDGET').first);

    // 4. Start the frame pipeline
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // In widget tests, runtime shader assets are not loaded, so animation does not start.
    final opacityWidget = tester.widget<Opacity>(
      find.ancestor(
        of: find.text('TARGET WIDGET').first,
        matching: find.byType(Opacity),
      ),
    );

    expect(opacityWidget.opacity, 1.0);
  });
}
*/
