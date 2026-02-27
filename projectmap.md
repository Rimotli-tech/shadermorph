# ShaderMorph Project Map (V2 — Deterministic Protocol)

## CORE PRINCIPLE
Framework = Semantic Intelligence (Metadata Extraction)
Shader = Deterministic Muscle (Pure Interpolation)

## REPOSITORY STRUCTURE
ShaderMorph/
├── core_shaders/
│   ├── engine/
│   │   └── morph_engine.frag      # The Unified Rendering Pipeline
│   ├── geometry/
│   │   └── remapping.glsl        # Math for Rect-to-Rect interpolation
│   └── styles/
│       ├── style_liquid.glsl     # Modular morph algorithms
│       └── style_glass.glsl
│
├── platforms/
│   ├── shadermorph_flutter/
│   │   ├── lib/
│   │   │   ├── src/
│   │   │   │   ├── tracker.dart   # Tagged element geometry extractor
│   │   │   │   ├── coordinator.dart # Metadata-to-Uniform mapper
│   │   │   │   └── registry.dart  # MorphStyle definitions
│   │   │   └── shadermorph.dart   # Public Hero-style API
│
└── docs/
    └── metadata_protocol_v2.md    # Specs for Rect-Array mapping

## UNIFORM CONTRACT (V2)
uniform float u_progress;         // 0..1 Global transition clock
uniform vec2  u_resolution;       // Viewport size
uniform int   u_morphStyle;       // Algorithm selector

// Element Metadata (Arrays)
uniform vec4  u_sourceRects[8];   // [x, y, w, h] normalized
uniform vec4  u_targetRects[8];   // [x, y, w, h] normalized
uniform int   u_pairCount;        // Active morph pairs

Uniform float packing order defined in docs/metadata_protocol_v2.md