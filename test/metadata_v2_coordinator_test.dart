import 'dart:ui' show Canvas, Image, Paint, PictureRecorder, Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:shadermorph_flutter/src/coordinator.dart';
import 'package:shadermorph_flutter/src/models.dart';
import 'package:shadermorph_flutter/src/models_v2.dart';

MorphPairRectsV2 _pair({
  required double sourceBase,
  required double targetBase,
}) {
  return MorphPairRectsV2(
    source: MorphRectNormV2(
      x: sourceBase + 0.01,
      y: sourceBase + 0.02,
      w: sourceBase + 0.03,
      h: sourceBase + 0.04,
    ),
    target: MorphRectNormV2(
      x: targetBase + 0.01,
      y: targetBase + 0.02,
      w: targetBase + 0.03,
      h: targetBase + 0.04,
    ),
  );
}

void main() {
  test('packV2UniformFloats follows strict protocol float order', () {
    final metadata = MorphFrameMetadataV2(
      resolutionPx: const Size(1920, 1080),
      progress: 0.75,
      morphStyle: 4,
      pairs: <MorphPairRectsV2>[
        _pair(sourceBase: 1.0, targetBase: 10.0),
        _pair(sourceBase: 2.0, targetBase: 20.0),
      ],
    );

    final packed = MorphCoordinator.packV2UniformFloats(metadata: metadata);

    expect(packed.length, MorphProtocolV2Constants.totalFloatCount);

    expect(packed[0], 1920.0);
    expect(packed[1], 1080.0);
    expect(packed[2], 0.75);
    expect(packed[3], 2.0);
    expect(packed[4], 4.0);

    expect(packed[5], 1.01);
    expect(packed[6], 1.02);
    expect(packed[7], 1.03);
    expect(packed[8], 1.04);

    expect(packed[9], 2.01);
    expect(packed[10], 2.02);
    expect(packed[11], 2.03);
    expect(packed[12], 2.04);

    expect(packed[37], 10.01);
    expect(packed[38], 10.02);
    expect(packed[39], 10.03);
    expect(packed[40], 10.04);

    expect(packed[41], 20.01);
    expect(packed[42], 20.02);
    expect(packed[43], 20.03);
    expect(packed[44], 20.04);

    for (var i = 13; i < 37; i += 1) {
      expect(packed[i], 0.0);
    }
    for (var i = 45; i < packed.length; i += 1) {
      expect(packed[i], 0.0);
    }
  });

  test('packV2UniformFloats truncates pairs beyond MAX_PAIRS', () {
    final pairs = List<MorphPairRectsV2>.generate(
      10,
      (i) => MorphPairRectsV2(
        source: MorphRectNormV2(
          x: i + 0.1,
          y: i + 0.2,
          w: i + 0.3,
          h: i + 0.4,
        ),
        target: MorphRectNormV2(
          x: i + 10.1,
          y: i + 10.2,
          w: i + 10.3,
          h: i + 10.4,
        ),
      ),
    );
    final metadata = MorphFrameMetadataV2(
      resolutionPx: const Size(100, 200),
      progress: 0.1,
      morphStyle: 2,
      pairs: pairs,
    );

    final packed = MorphCoordinator.packV2UniformFloats(metadata: metadata);

    expect(packed[3], 8.0);

    final sourceIndex7 = 5 + (7 * 4);
    expect(packed[sourceIndex7], 7.1);
    expect(packed[sourceIndex7 + 1], 7.2);
    expect(packed[sourceIndex7 + 2], 7.3);
    expect(packed[sourceIndex7 + 3], 7.4);

    final targetIndex7 = 37 + (7 * 4);
    expect(packed[targetIndex7], 17.1);
    expect(packed[targetIndex7 + 1], 17.2);
    expect(packed[targetIndex7 + 2], 17.3);
    expect(packed[targetIndex7 + 3], 17.4);
  });

  test('buildSinglePairMetadataV2 converts logical snapshots with DPR', () {
    final metadata = MorphCoordinator.buildSinglePairMetadataV2(
      logicalViewport: const Size(100, 200),
      sourceRect: MorphSnapshot(
        image: _tinyImage(),
        rect: const Rect.fromLTWH(10, 20, 30, 40),
        pixelRatio: 2.0,
      ),
      targetRect: MorphSnapshot(
        image: _tinyImage(),
        rect: const Rect.fromLTWH(20, 40, 10, 20),
        pixelRatio: 2.0,
      ),
      progress: 0.6,
      morphStyle: 7,
    );

    expect(metadata.resolutionPx, const Size(200, 400));
    expect(metadata.progress, 0.6);
    expect(metadata.morphStyle, 7);
    expect(metadata.pairCount, 1);

    final source = metadata.sourceRectsFixed8.first;
    final target = metadata.targetRectsFixed8.first;

    expect(source, const MorphRectNormV2(x: 0.1, y: 0.1, w: 0.3, h: 0.2));
    expect(target, const MorphRectNormV2(x: 0.2, y: 0.2, w: 0.1, h: 0.1));
  });

  test('buildSinglePairMetadataV2 can use logical resolution for shader space', () {
    final metadata = MorphCoordinator.buildSinglePairMetadataV2(
      logicalViewport: const Size(100, 200),
      sourceRect: MorphSnapshot(
        image: _tinyImage(),
        rect: const Rect.fromLTWH(10, 20, 30, 40),
        pixelRatio: 2.0,
      ),
      targetRect: MorphSnapshot(
        image: _tinyImage(),
        rect: const Rect.fromLTWH(20, 40, 10, 20),
        pixelRatio: 2.0,
      ),
      progress: 0.6,
      morphStyle: 7,
      usePhysicalResolution: false,
    );

    expect(metadata.resolutionPx, const Size(100, 200));
    expect(metadata.sourceRectsFixed8.first, const MorphRectNormV2(x: 0.1, y: 0.1, w: 0.3, h: 0.2));
    expect(metadata.targetRectsFixed8.first, const MorphRectNormV2(x: 0.2, y: 0.2, w: 0.1, h: 0.1));
  });
}

// Tests only need a valid ui.Image instance; a 1x1 image is sufficient.
Image _tinyImage() {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 1, 1), Paint());
  final picture = recorder.endRecording();
  return picture.toImageSync(1, 1);
}
