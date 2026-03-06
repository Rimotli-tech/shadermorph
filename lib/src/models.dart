import 'dart:ui' as ui;
import 'package:flutter/material.dart';

enum MorphShadowCapturePolicy { exclude, include }

enum MorphDirection { forward, reverse }

/// Holds the visual and spatial state of a widget at the moment of capture.
class MorphSnapshot {
  final ui.Image image;
  final Rect rect;
  final double pixelRatio;
  bool _disposed = false;

  MorphSnapshot({
    required this.image,
    required this.rect,
    required this.pixelRatio,
  });

  Size get size => rect.size;
  Offset get position => rect.topLeft;

  bool get isDisposed => _disposed;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_isImageDisposed(image)) return;
    image.dispose();
  }

  static bool _isImageDisposed(ui.Image image) {
    bool disposed = false;
    assert(() {
      disposed = image.debugDisposed;
      return true;
    }());
    return disposed;
  }
}

class MorphPairSnapshot {
  final MorphSnapshot source;
  final MorphSnapshot destination;
  bool _disposed = false;

  MorphPairSnapshot({required this.source, required this.destination});

  bool get isDisposed => _disposed;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    source.dispose();
    if (!identical(source, destination)) {
      destination.dispose();
    }
  }
}
