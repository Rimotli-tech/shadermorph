import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadermorph_flutter/shadermorph_flutter.dart';

void main() {
  testWidgets('ShaderMorph renders child and responds to tap', (tester) async {
    // 1. Build the widget with a required child
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ShaderMorph(child: Text('TARGET WIDGET'))),
      ),
    );

    // 2. Verify the initial state: The child text should be visible
    expect(find.text('TARGET WIDGET'), findsOneWidget);

    // 3. Trigger the morph by tapping the widget
    await tester.tap(find.text('TARGET WIDGET'));

    // 4. Start the animation frames
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // After tapping, the ShaderMorph enters "animating" state.
    // In our logic, the real widget Opacity becomes 0.0.
    final opacityWidget = tester.widget<Opacity>(
      find.ancestor(
        of: find.text('TARGET WIDGET'),
        matching: find.byType(Opacity),
      ),
    );

    expect(opacityWidget.opacity, 0.0);
  });
}
