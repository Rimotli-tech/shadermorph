import 'package:flutter/widgets.dart';

class GeometryTracker {
  const GeometryTracker._();

  static Rect? extractLogicalRect(BuildContext context) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.hasSize ||
        !renderObject.attached) {
      return null;
    }
    final topLeft = renderObject.localToGlobal(Offset.zero);
    return topLeft & renderObject.size;
  }

}
