import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Controls whether shadow or decoration pixels outside the main child bounds
/// are included in capture snapshots.
enum MorphShadowCapturePolicy { exclude, include }

/// Playback direction for a morph transition.
enum MorphDirection { forward, reverse }

/// Holds the visual and spatial state of a widget at the moment of capture.
class MorphSnapshot {
  /// The captured raster image for the endpoint.
  final ui.Image image;
  /// The captured endpoint rect in logical pixels.
  final Rect rect;
  /// Device pixel ratio used when the snapshot was captured.
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
  /// Origin endpoint snapshot used for the current morph.
  final MorphSnapshot origin;
  /// Destination endpoint snapshot used for the current morph.
  final MorphSnapshot destination;
  bool _disposed = false;

  MorphPairSnapshot({required this.origin, required this.destination});

  bool get isDisposed => _disposed;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    origin.dispose();
    if (!identical(origin, destination)) {
      destination.dispose();
    }
  }
}
