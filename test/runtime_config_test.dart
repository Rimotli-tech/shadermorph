import 'package:flutter_test/flutter_test.dart';
import 'package:shadermorph_flutter/src/runtime_config.dart';

void main() {
  test('resolve defaults to V2 render on both paths', () {
    final config = MorphRuntimeConfig.resolve(
      forceV1Fallback: false,
      shadowBindRequested: false,
    );

    expect(config.useV2SinglePageRender, isTrue);
    expect(config.useV2CrossRouteRender, isTrue);
    expect(config.forceV1Fallback, isFalse);
    expect(config.enableV2ShadowBindWhenV1, isFalse);
    expect(config.usedLegacySinglePageFlag, isFalse);
    expect(config.usedLegacyCrossRouteFlag, isFalse);
  });

  test('force V1 disables V2 render and allows optional V2 shadow bind', () {
    final config = MorphRuntimeConfig.resolve(
      forceV1Fallback: true,
      shadowBindRequested: true,
    );

    expect(config.forceV1Fallback, isTrue);
    expect(config.useV2SinglePageRender, isFalse);
    expect(config.useV2CrossRouteRender, isFalse);
    expect(config.enableV2ShadowBindWhenV1, isTrue);
  });

  test('legacy flags are mapped and marked as used', () {
    final config = MorphRuntimeConfig.resolve(
      forceV1Fallback: false,
      shadowBindRequested: false,
      legacySinglePageFlagRaw: 'false',
      legacyCrossRouteFlagRaw: 'true',
    );

    expect(config.useV2SinglePageRender, isFalse);
    expect(config.useV2CrossRouteRender, isTrue);
    expect(config.usedLegacySinglePageFlag, isTrue);
    expect(config.usedLegacyCrossRouteFlag, isTrue);
  });
}
