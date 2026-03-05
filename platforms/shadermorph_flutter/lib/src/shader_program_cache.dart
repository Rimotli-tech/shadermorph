import 'dart:ui' as ui;

/// Shared process-wide shader cache used by host and cross-route engines.
class ShaderMorphProgramBundle {
  final ui.FragmentProgram v1Program;
  final ui.FragmentProgram? v2Program;

  const ShaderMorphProgramBundle({
    required this.v1Program,
    required this.v2Program,
  });
}

class ShaderMorphProgramCache {
  ShaderMorphProgramCache._();

  static ShaderMorphProgramBundle? _cached;
  static Future<ShaderMorphProgramBundle?>? _inflight;

  static ShaderMorphProgramBundle? get cached => _cached;

  /// Preloads shader assets once to avoid first-hit runtime compilation stalls.
  static Future<ShaderMorphProgramBundle?> prewarm() {
    if (_cached != null) {
      return Future<ShaderMorphProgramBundle?>.value(_cached);
    }
    final inflight = _inflight;
    if (inflight != null) return inflight;
    _inflight = _loadBundle();
    return _inflight!;
  }

  static Future<ShaderMorphProgramBundle?> loadOrGet() async {
    return _cached ?? await prewarm();
  }

  static Future<ShaderMorphProgramBundle?> _loadBundle() async {
    try {
      final v1 = await ui.FragmentProgram.fromAsset(
        'packages/shadermorph_flutter/shaders/shader_engine.frag',
      );
      ui.FragmentProgram? v2;
      try {
        v2 = await ui.FragmentProgram.fromAsset(
          'packages/shadermorph_flutter/shaders/shader_engine_v2.frag',
        );
      } catch (_) {
        // Keep fallback availability if V2 cannot load.
      }
      final bundle = ShaderMorphProgramBundle(v1Program: v1, v2Program: v2);
      _cached = bundle;
      return bundle;
    } catch (_) {
      return null;
    } finally {
      _inflight = null;
    }
  }
}
