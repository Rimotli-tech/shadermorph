import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  test('gallery app widget can be constructed', () {
    const app = MorphPaperRipDemoApp();
    expect(app, isA<Widget>());
  });
}