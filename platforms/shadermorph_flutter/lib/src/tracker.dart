import 'dart:ui' as ui;

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

  static Rect? extractPhysicalRect(BuildContext context) {
    final logical = extractLogicalRect(context);
    if (logical == null) {
      return null;
    }
    final dpr = View.of(context).devicePixelRatio;
    return Rect.fromLTWH(
      logical.left * dpr,
      logical.top * dpr,
      logical.width * dpr,
      logical.height * dpr,
    );
  }

  static ui.Size logicalToPhysicalSize(BuildContext context, Size logicalSize) {
    final dpr = View.of(context).devicePixelRatio;
    return ui.Size(logicalSize.width * dpr, logicalSize.height * dpr);
  }
}
