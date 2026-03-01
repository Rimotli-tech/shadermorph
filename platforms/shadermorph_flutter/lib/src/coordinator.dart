import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'models.dart';

class MorphCoordinator {
  static void setUniforms({
    required ui.FragmentShader shader,
    required Size viewport,
    required MorphSnapshot
    sourceRect, // Using your name to represent the source data
    required double time,
    required double progress, // New: Slot 7
  }) {
    // uSize
    shader.setFloat(0, viewport.width);
    shader.setFloat(1, viewport.height);

    // uSourceRect logic using the snapshot object
    shader.setFloat(2, sourceRect.rect.left);
    shader.setFloat(3, sourceRect.rect.top);
    shader.setFloat(4, sourceRect.rect.width);
    shader.setFloat(5, sourceRect.rect.height);

    shader.setFloat(6, time);
    shader.setFloat(7, progress);

    // uTexture (Sampler 0)
    shader.setImageSampler(0, sourceRect.image);
  }
}
