import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'models.dart';

class MorphTracker {
  static Future<MorphSnapshot> capture(GlobalKey key) async {
    final context = key.currentContext;
    if (context == null) throw Exception("MorphTracker: Context not found.");

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
    final pixelRatio = View.of(context).devicePixelRatio;
    final image = await boundary.toImage(pixelRatio: pixelRatio);

    return MorphSnapshot(image: image, rect: rect, pixelRatio: pixelRatio);
  }
}
