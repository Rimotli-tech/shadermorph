import 'package:flutter_test/flutter_test.dart';
import 'package:shadermorph_flutter/src/models_v2.dart';
import 'package:shadermorph_flutter/src/tracker.dart';
import 'package:flutter/widgets.dart';

void main() {
  test('logicalRectToPhysicalRect multiplies by devicePixelRatio', () {
    final physical = MorphTracker.logicalRectToPhysicalRect(
      logicalRect: const Rect.fromLTWH(10, 20, 30, 40),
      devicePixelRatio: 2.5,
    );

    expect(physical, const Rect.fromLTWH(25, 50, 75, 100));
  });

  test('logicalSizeToPhysicalSize multiplies by devicePixelRatio', () {
    final physical = MorphTracker.logicalSizeToPhysicalSize(
      logicalSize: const Size(100, 200),
      devicePixelRatio: 3.0,
    );

    expect(physical, const Size(300, 600));
  });

  test('normalizePhysicalRectToV2 maps rect to normalized coordinates', () {
    final normalized = MorphTracker.normalizePhysicalRectToV2(
      physicalRect: const Rect.fromLTWH(20, 40, 60, 80),
      resolutionPx: const Size(200, 400),
    );

    expect(
      normalized,
      const MorphRectNormV2(x: 0.1, y: 0.1, w: 0.3, h: 0.2),
    );
  });

  test('normalizeLogicalRectToV2 performs DPR conversion before normalize', () {
    final normalized = MorphTracker.normalizeLogicalRectToV2(
      logicalRect: const Rect.fromLTWH(10, 20, 30, 40),
      logicalResolution: const Size(100, 200),
      devicePixelRatio: 2.0,
    );

    expect(
      normalized,
      const MorphRectNormV2(x: 0.1, y: 0.1, w: 0.3, h: 0.2),
    );
  });

  test('normalizePhysicalRectToV2 keeps overscroll values when unclamped', () {
    final normalized = MorphTracker.normalizePhysicalRectToV2(
      physicalRect: const Rect.fromLTWH(-10, 0, 120, 200),
      resolutionPx: const Size(100, 100),
      clampToUnit: false,
    );

    expect(
      normalized,
      const MorphRectNormV2(x: -0.1, y: 0.0, w: 1.2, h: 2.0),
    );
  });

  test('normalizePhysicalRectToV2 clamps when clampToUnit is enabled', () {
    final normalized = MorphTracker.normalizePhysicalRectToV2(
      physicalRect: const Rect.fromLTWH(-10, 0, 120, 200),
      resolutionPx: const Size(100, 100),
      clampToUnit: true,
    );

    expect(
      normalized,
      const MorphRectNormV2(x: 0.0, y: 0.0, w: 1.0, h: 1.0),
    );
  });

  test('normalize helpers return zero on invalid resolution or DPR', () {
    final badResolution = MorphTracker.normalizePhysicalRectToV2(
      physicalRect: const Rect.fromLTWH(10, 10, 10, 10),
      resolutionPx: const Size(0, 100),
    );
    final badDpr = MorphTracker.normalizeLogicalRectToV2(
      logicalRect: const Rect.fromLTWH(10, 10, 10, 10),
      logicalResolution: const Size(100, 100),
      devicePixelRatio: 0.0,
    );

    expect(badResolution, MorphRectNormV2.zero);
    expect(badDpr, MorphRectNormV2.zero);
  });
}
