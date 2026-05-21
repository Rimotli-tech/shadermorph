import 'dart:ui' as ui;

/// Shared process-wide shader cache used by host and cross-route engines.
class ShaderMorphProgramBundle {
  final ui.FragmentProgram program;
  final ui.FragmentProgram? shapeAwareProgram;

  const ShaderMorphProgramBundle({
    required this.program,
    required this.shapeAwareProgram,
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
      final program = await ui.FragmentProgram.fromAsset(
        'packages/shadermorph_flutter/shaders/shader_engine.frag',
      );
      ui.FragmentProgram? shapeAware;
      try {
        shapeAware = await ui.FragmentProgram.fromAsset(
          'packages/shadermorph_flutter/shaders/shader_engine_shape_aware.frag',
        );
      } catch (_) {
        // Keep the shared engine available if this style shader cannot load.
      }
      final bundle = ShaderMorphProgramBundle(
        program: program,
        shapeAwareProgram: shapeAware,
      );
      _cached = bundle;
      return bundle;
    } catch (_) {
      return null;
    } finally {
      _inflight = null;
    }
  }
}
