import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Holds the visual and spatial state of a widget at the moment of capture.
class MorphSnapshot {
  final ui.Image image;
  final Rect rect;
  final double pixelRatio;

  MorphSnapshot({
    required this.image,
    required this.rect,
    required this.pixelRatio,
  });

  Size get size => rect.size;
  Offset get position => rect.topLeft;
}
