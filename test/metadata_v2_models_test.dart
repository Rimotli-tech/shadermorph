import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:shadermorph_flutter/src/models_v2.dart';

MorphPairRectsV2 _pair(double seed, {String? id}) {
  return MorphPairRectsV2(
    id: id,
    source: MorphRectNormV2(x: seed, y: seed + 0.1, w: 0.2, h: 0.3),
    target: MorphRectNormV2(x: seed + 0.4, y: seed + 0.5, w: 0.6, h: 0.7),
  );
}

void main() {
  test('pairCount clamps to maxPairs (8)', () {
    final metadata = MorphFrameMetadataV2(
      resolutionPx: const Size(1080, 1920),
      progress: 0.5,
      morphStyle: 1,
      pairs: List<MorphPairRectsV2>.generate(10, (i) => _pair(i.toDouble())),
    );

    expect(metadata.pairCount, 8);
    expect(metadata.sourceRectsFixed8.length, 8);
    expect(metadata.targetRectsFixed8.length, 8);
  });

  test('fixed arrays zero-fill when pair count is below maxPairs', () {
    final metadata = MorphFrameMetadataV2(
      resolutionPx: const Size(1080, 1920),
      progress: 0.25,
      morphStyle: 2,
      pairs: <MorphPairRectsV2>[_pair(1.0), _pair(2.0)],
    );

    final sources = metadata.sourceRectsFixed8;
    final targets = metadata.targetRectsFixed8;

    expect(sources[0], const MorphRectNormV2(x: 1.0, y: 1.1, w: 0.2, h: 0.3));
    expect(sources[1], const MorphRectNormV2(x: 2.0, y: 2.1, w: 0.2, h: 0.3));
    expect(targets[0], const MorphRectNormV2(x: 1.4, y: 1.5, w: 0.6, h: 0.7));
    expect(targets[1], const MorphRectNormV2(x: 2.4, y: 2.5, w: 0.6, h: 0.7));

    for (var i = 2; i < MorphProtocolV2Constants.maxPairs; i += 1) {
      expect(sources[i], MorphRectNormV2.zero);
      expect(targets[i], MorphRectNormV2.zero);
    }
  });

  test('clampedToUnit clamps every field into [0, 1]', () {
    const rect = MorphRectNormV2(x: -0.5, y: 1.3, w: 4.2, h: -2.0);
    final clamped = rect.clampedToUnit();

    expect(clamped, const MorphRectNormV2(x: 0.0, y: 1.0, w: 1.0, h: 0.0));
  });

  test('metadata preserves provided pair ordering', () {
    final metadata = MorphFrameMetadataV2(
      resolutionPx: const Size(1080, 1920),
      progress: 0.9,
      morphStyle: 3,
      pairs: <MorphPairRectsV2>[
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
    expect(MorphProtocolV2Constants.totalFloatCount, 69);
    expect(MorphProtocolV2Constants.scalarFloatCount, 5);
    expect(MorphProtocolV2Constants.rectFloatCountPerSide, 32);
    expect(MorphProtocolV2Constants.maxPairs, 8);
  });

  test('isFiniteAndNonNegativeSize validates finite values and size sign', () {
    const ok = MorphRectNormV2(x: 0.1, y: 0.2, w: 0.3, h: 0.4);
    const badNegative = MorphRectNormV2(x: 0.1, y: 0.2, w: -0.3, h: 0.4);
    const badNan = MorphRectNormV2(x: double.nan, y: 0.2, w: 0.3, h: 0.4);

    expect(ok.isFiniteAndNonNegativeSize, isTrue);
    expect(badNegative.isFiniteAndNonNegativeSize, isFalse);
    expect(badNan.isFiniteAndNonNegativeSize, isFalse);
  });
}
