import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app builds and toggle works', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ShaderMorph()));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('Toggle Morph'), findsOneWidget);
    await tester.tap(find.text('Toggle Morph'));
    await tester.pump(const Duration(milliseconds: 16));
  });
}
