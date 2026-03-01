import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class MorphTracker {
  static Future<Map<String, dynamic>> capture(GlobalKey key) async {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) throw Exception("Could not find RenderBox");

    // Get Global Position
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final rect = Rect.fromLTWH(
      position.dx,
      position.dy,
      size.width,
      size.height,
    );

    // Get Pixels
    final boundary = renderBox as RenderRepaintBoundary;
    final image = await boundary.toImage(
      pixelRatio: ui.window.devicePixelRatio,
    );

    return {'image': image, 'rect': rect};
  }
}
