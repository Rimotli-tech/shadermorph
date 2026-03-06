import 'package:flutter/foundation.dart';

const String _unset = '__unset__';

class MorphRuntimeConfig {
  final bool useV2SinglePageRender;
  final bool useV2CrossRouteRender;
  final bool forceV1Fallback;
  final bool enableV2ShadowBindWhenV1;
  final bool usedLegacySinglePageFlag;
  final bool usedLegacyCrossRouteFlag;

  const MorphRuntimeConfig({
    required this.useV2SinglePageRender,
    required this.useV2CrossRouteRender,
    required this.forceV1Fallback,
    required this.enableV2ShadowBindWhenV1,
    required this.usedLegacySinglePageFlag,
    required this.usedLegacyCrossRouteFlag,
  });

  static final MorphRuntimeConfig current = fromEnvironment();

  static MorphRuntimeConfig fromEnvironment() {
    return resolve(
      forceV1Fallback: const bool.fromEnvironment(
        'SHADERMORPH_FORCE_V1_RENDER',
        defaultValue: false,
      ),
      shadowBindRequested: const bool.fromEnvironment(
        'SHADERMORPH_V2_SHADOW_BIND',
        defaultValue: false,
      ),
      legacySinglePageFlagRaw: const String.fromEnvironment(
        'SHADERMORPH_V2_RENDER_SINGLE_PAGE',
        defaultValue: _unset,
      ),
      legacyCrossRouteFlagRaw: const String.fromEnvironment(
        'SHADERMORPH_V2_RENDER_CROSS_ROUTE',
        defaultValue: _unset,
      ),
    );
  }

  static MorphRuntimeConfig resolve({
    required bool forceV1Fallback,
    required bool shadowBindRequested,
    String legacySinglePageFlagRaw = _unset,
    String legacyCrossRouteFlagRaw = _unset,
  }) {
    final legacySingle = _parseOptionalBool(legacySinglePageFlagRaw);
    final legacyCross = _parseOptionalBool(legacyCrossRouteFlagRaw);

    final useV2Single = legacySingle ?? true;
    final useV2Cross = legacyCross ?? true;

    return MorphRuntimeConfig(
      useV2SinglePageRender: !forceV1Fallback && useV2Single,
      useV2CrossRouteRender: !forceV1Fallback && useV2Cross,
      forceV1Fallback: forceV1Fallback,
      enableV2ShadowBindWhenV1: forceV1Fallback && shadowBindRequested,
      usedLegacySinglePageFlag: legacySingle != null,
      usedLegacyCrossRouteFlag: legacyCross != null,
    );
  }

  // Deprecated path: use SHADERMORPH_FORCE_V1_RENDER for fallback control.
  @Deprecated('Use SHADERMORPH_FORCE_V1_RENDER for fallback control.')
  static MorphRuntimeConfig fromDeprecatedV2RenderFlags() {
    final forceV1 = const bool.fromEnvironment(
      'SHADERMORPH_FORCE_V1_RENDER',
      defaultValue: false,
    );
    final shadowRequested = const bool.fromEnvironment(
      'SHADERMORPH_V2_SHADOW_BIND',
      defaultValue: false,
    );

    final legacySingleRaw = const String.fromEnvironment(
      'SHADERMORPH_V2_RENDER_SINGLE_PAGE',
      defaultValue: _unset,
    );
    final legacyCrossRaw = const String.fromEnvironment(
      'SHADERMORPH_V2_RENDER_CROSS_ROUTE',
      defaultValue: _unset,
    );

    final legacySingle = _parseOptionalBool(legacySingleRaw);
    final legacyCross = _parseOptionalBool(legacyCrossRaw);

    final useV2Single = legacySingle ?? true;
    final useV2Cross = legacyCross ?? true;

    return MorphRuntimeConfig(
      useV2SinglePageRender: !forceV1 && useV2Single,
      useV2CrossRouteRender: !forceV1 && useV2Cross,
      forceV1Fallback: forceV1,
      enableV2ShadowBindWhenV1: forceV1 && shadowRequested,
      usedLegacySinglePageFlag: legacySingle != null,
      usedLegacyCrossRouteFlag: legacyCross != null,
    );
  }

  static bool? _parseOptionalBool(String raw) {
    final normalized = raw.toLowerCase().trim();
    if (normalized == _unset) return null;
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
    return null;
  }
}

bool _didLogDeprecation = false;

void maybeLogRuntimeDeprecations(MorphRuntimeConfig config) {
  if (_didLogDeprecation) return;
  final legacyUsed =
      config.usedLegacySinglePageFlag || config.usedLegacyCrossRouteFlag;
  if (!legacyUsed) return;
  _didLogDeprecation = true;
  debugPrint(
    'ShaderMorph: Deprecated flags in use: '
    'SHADERMORPH_V2_RENDER_SINGLE_PAGE / SHADERMORPH_V2_RENDER_CROSS_ROUTE. '
    'Use SHADERMORPH_FORCE_V1_RENDER for emergency fallback.',
  );
}
