import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;

class MorphCoordinator {
  static void setUniforms({
    required ui.FragmentShader shader,
    required Size viewport,
    required Rect sourceRect,
    required ui.Image texture,
    required double time,
  }) {
    // uSize
    shader.setFloat(0, viewport.width);
    shader.setFloat(1, viewport.height);
    shader.setFloat(2, sourceRect.left);
    shader.setFloat(3, sourceRect.top);
    shader.setFloat(4, sourceRect.width);
    shader.setFloat(5, sourceRect.height);
    shader.setFloat(6, time);

    // uTexture (Sampler 0)
    shader.setImageSampler(0, texture);
  }
}
