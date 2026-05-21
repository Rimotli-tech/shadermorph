import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:shadermorph_flutter/src/metadata.dart';
import 'package:shadermorph_flutter/src/shape.dart';

MorphPairRects _pair(double seed, {String? id}) {
  return MorphPairRects(
    id: id,
    source: MorphRectNorm(x: seed, y: seed + 0.1, w: 0.2, h: 0.3),
    target: MorphRectNorm(x: seed + 0.4, y: seed + 0.5, w: 0.6, h: 0.7),
  );
}

void main() {
  test('pairCount clamps to maxPairs (8)', () {
    final metadata = MorphFrameMetadata(
      resolutionPx: const Size(1080, 1920),
      progress: 0.5,
      morphStyle: 1,
      pairs: List<MorphPairRects>.generate(10, (i) => _pair(i.toDouble())),
    );

    expect(metadata.pairCount, 8);
    expect(metadata.sourceRectsFixed8.length, 8);
    expect(metadata.targetRectsFixed8.length, 8);
  });

  test('fixed arrays zero-fill when pair count is below maxPairs', () {
    final metadata = MorphFrameMetadata(
      resolutionPx: const Size(1080, 1920),
      progress: 0.25,
      morphStyle: 2,
      pairs: <MorphPairRects>[_pair(1.0), _pair(2.0)],
    );

    final sources = metadata.sourceRectsFixed8;
    final targets = metadata.targetRectsFixed8;
    final sourceShapes = metadata.sourceShapesFixed8;
    final targetShapes = metadata.targetShapesFixed8;

    expect(sources[0], const MorphRectNorm(x: 1.0, y: 1.1, w: 0.2, h: 0.3));
    expect(sources[1], const MorphRectNorm(x: 2.0, y: 2.1, w: 0.2, h: 0.3));
    expect(targets[0], const MorphRectNorm(x: 1.4, y: 1.5, w: 0.6, h: 0.7));
    expect(targets[1], const MorphRectNorm(x: 2.4, y: 2.5, w: 0.6, h: 0.7));

    for (var i = 2; i < MorphProtocolConstants.maxPairs; i += 1) {
      expect(sources[i], MorphRectNorm.zero);
      expect(targets[i], MorphRectNorm.zero);
      expect(sourceShapes[i], MorphShapeData.rect);
      expect(targetShapes[i], MorphShapeData.rect);
    }
  });

  test('shape data converts public shapes into shader metadata', () {
    final rounded = MorphShapeData.fromShape(
      shape: const MorphShape.roundedRect(radius: 12),
      logicalRect: const Rect.fromLTWH(0, 0, 120, 60),
    );
    final circle = MorphShapeData.fromShape(
      shape: const MorphShape.circle(),
      logicalRect: const Rect.fromLTWH(0, 0, 40, 40),
    );

    expect(rounded.type, 1.0);
    expect(rounded.radiusRatio, 0.2);
    expect(circle.type, 2.0);
    expect(circle.radiusRatio, 0.5);
  });

  test('clampedToUnit clamps every field into [0, 1]', () {
    const rect = MorphRectNorm(x: -0.5, y: 1.3, w: 4.2, h: -2.0);
    final clamped = rect.clampedToUnit();

    expect(clamped, const MorphRectNorm(x: 0.0, y: 1.0, w: 1.0, h: 0.0));
  });

  test('metadata preserves provided pair ordering', () {
    final metadata = MorphFrameMetadata(
      resolutionPx: const Size(1080, 1920),
      progress: 0.9,
      morphStyle: 3,
      pairs: <MorphPairRects>[
        _pair(2.0, id: 'b'),
        _pair(1.0, id: 'a'),
        _pair(3.0, id: 'c'),
      ],
    );

    final sources = metadata.sourceRectsFixed8;
    expect(sources[0].x, 2.0);
    expect(sources[1].x, 1.0);
    expect(sources[2].x, 3.0);
  });

  test('protocol constants lock expected total float count', () {
    expect(MorphProtocolConstants.totalFloatCount, 133);
    expect(MorphProtocolConstants.scalarFloatCount, 5);
    expect(MorphProtocolConstants.rectFloatCountPerSide, 32);
    expect(MorphProtocolConstants.shapeFloatCountPerSide, 32);
    expect(MorphProtocolConstants.maxPairs, 8);
  });

  test('isFiniteAndNonNegativeSize validates finite values and size sign', () {
    const ok = MorphRectNorm(x: 0.1, y: 0.2, w: 0.3, h: 0.4);
    const badNegative = MorphRectNorm(x: 0.1, y: 0.2, w: -0.3, h: 0.4);
    const badNan = MorphRectNorm(x: double.nan, y: 0.2, w: 0.3, h: 0.4);

    expect(ok.isFiniteAndNonNegativeSize, isTrue);
    expect(badNegative.isFiniteAndNonNegativeSize, isFalse);
    expect(badNan.isFiniteAndNonNegativeSize, isFalse);
  });
}
