import 'dart:typed_data';
import 'dart:ui' as ui;

import 'registry.dart';

class MorphRect {
  const MorphRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  const MorphRect.zero() : x = 0, y = 0, width = 0, height = 0;

  final double x;
  final double y;
  final double width;
  final double height;
}

class MorphMetadata {
  const MorphMetadata({
    required this.pairCount,
    required this.sourceRects,
    required this.targetRects,
    required this.signature,
  });

  final int pairCount;
  final List<MorphRect> sourceRects;
  final List<MorphRect> targetRects;
  final String signature;

  static MorphMetadata empty() {
    final zeroRects = List<MorphRect>.generate(
      MetadataCoordinator.maxPairs,
      (_) => const MorphRect.zero(),
    );
    return MorphMetadata(
      pairCount: 0,
      sourceRects: zeroRects,
      targetRects: zeroRects,
      signature: 'empty',
    );
  }

  Float32List flattenRects(List<MorphRect> rects) {
    final out = Float32List(MetadataCoordinator.maxPairs * 4);
    for (int i = 0; i < MetadataCoordinator.maxPairs; i++) {
      final base = i * 4;
      final rect = rects[i];
      out[base + 0] = rect.x.toDouble();
      out[base + 1] = rect.y.toDouble();
      out[base + 2] = rect.width.toDouble();
      out[base + 3] = rect.height.toDouble();
    }
    return out;
  }

  Float32List get flattenedSourceRects => flattenRects(sourceRects);
  Float32List get flattenedTargetRects => flattenRects(targetRects);
}

class MetadataCoordinator {
  MetadataCoordinator({ShaderMorphTagRegistry? registry})
    : _registry = registry ?? ShaderMorphTagRegistry.instance;

  static const int maxPairs = 8;

  final ShaderMorphTagRegistry _registry;
  String? _lastSignature;

  MorphMetadata? buildIfChanged({
    required String sourceScreenId,
    required String targetScreenId,
    required ui.Size resolutionPx,
  }) {
    final metadata = build(
      sourceScreenId: sourceScreenId,
      targetScreenId: targetScreenId,
      resolutionPx: resolutionPx,
    );
    if (_lastSignature == metadata.signature) {
      return null;
    }
    _lastSignature = metadata.signature;
    return metadata;
  }

  MorphMetadata build({
    required String sourceScreenId,
    required String targetScreenId,
    required ui.Size resolutionPx,
  }) {
    final sourceTags = _registry.getTagsForScreen(sourceScreenId);
    final targetTags = _registry.getTagsForScreen(targetScreenId);
    final ids = sourceTags.keys.where(targetTags.containsKey).toList()..sort();

    final safeWidth = resolutionPx.width <= 0 ? 1.0 : resolutionPx.width;
    final safeHeight = resolutionPx.height <= 0 ? 1.0 : resolutionPx.height;

    final sourceRects = <MorphRect>[];
    final targetRects = <MorphRect>[];

    for (final id in ids) {
      if (sourceRects.length >= maxPairs) {
        break;
      }
      final src = sourceTags[id]?.physicalRect;
      final dst = targetTags[id]?.physicalRect;
      if (src == null || dst == null) {
        continue;
      }

      sourceRects.add(
        MorphRect(
          x: src.left / safeWidth,
          y: src.top / safeHeight,
          width: src.width / safeWidth,
          height: src.height / safeHeight,
        ),
      );
      targetRects.add(
        MorphRect(
          x: dst.left / safeWidth,
          y: dst.top / safeHeight,
          width: dst.width / safeWidth,
          height: dst.height / safeHeight,
        ),
      );
    }

    final pairCount = sourceRects.length;

    while (sourceRects.length < maxPairs) {
      sourceRects.add(const MorphRect.zero());
      targetRects.add(const MorphRect.zero());
    }
    final signature = _signatureFromRects(
      pairCount: pairCount,
      sourceRects: sourceRects,
      targetRects: targetRects,
    );

    return MorphMetadata(
      pairCount: pairCount,
      sourceRects: sourceRects,
      targetRects: targetRects,
      signature: signature,
    );
  }

  String _signatureFromRects({
    required int pairCount,
    required List<MorphRect> sourceRects,
    required List<MorphRect> targetRects,
  }) {
    final buffer = StringBuffer()..write(pairCount);
    for (int i = 0; i < maxPairs; i++) {
      final s = sourceRects[i];
      final t = targetRects[i];
      buffer
        ..write('|')
        ..write(s.x.toStringAsFixed(6))
        ..write(',')
        ..write(s.y.toStringAsFixed(6))
        ..write(',')
        ..write(s.width.toStringAsFixed(6))
        ..write(',')
        ..write(s.height.toStringAsFixed(6))
        ..write('|')
        ..write(t.x.toStringAsFixed(6))
        ..write(',')
        ..write(t.y.toStringAsFixed(6))
        ..write(',')
        ..write(t.width.toStringAsFixed(6))
        ..write(',')
        ..write(t.height.toStringAsFixed(6));
    }
    return buffer.toString();
  }
}
