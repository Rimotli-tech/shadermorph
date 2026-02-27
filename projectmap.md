# ShaderMorph Project Map

ShaderMorph is a cross-platform GPU transition engine structured as a monorepo.

The architecture is designed for:
- Strict separation of concerns
- Long-term scalability
- Clean dependency direction
- Zero structural refactoring when adding platforms
- Core shader portability across frameworks

------------------------------------------------------------
CORE PRINCIPLE
------------------------------------------------------------

Core GLSL is the source of truth.

Platforms depend on core.
Core never depends on platforms.
Platforms never depend on each other.

Dependency direction:

core_shaders  → (no dependencies)
platforms/*   → core_shaders

------------------------------------------------------------
REPOSITORY STRUCTURE
------------------------------------------------------------

ShaderMorph/
│
├── .vscode/                # Shared IDE settings and workspace rules
│
├── docs/                   # Documentation and public-facing specs
│   ├── shader_spec.md
│   ├── uniform_contract.md
│   └── roadmap.md
│
├── core_shaders/           # Framework-agnostic GLSL source of truth
│   │
│   ├── transitions/        # Transition shaders only
│   │   ├── morph_basic.frag
│   │   ├── morph_advanced.frag
│   │   └── ...
│   │
│   ├── effects/            # Reusable shader effects
│   │   ├── blur.frag
│   │   ├── noise.frag
│   │   └── distort.frag
│   │
│   └── includes/           # Shared GLSL utilities
│       ├── uniforms.glsl
│       ├── easing.glsl
│       ├── math.glsl
│       └── common.glsl
│
├── platforms/              # Framework-specific adapters
│   │
│   ├── shadermorph_flutter/
│   │   ├── lib/
│   │   ├── test/
│   │   └── pubspec.yaml
│   │
│   ├── shadermorph_react/
│   │
│   ├── shadermorph_kotlin/
│   │
│   └── shadermorph_swift/
│
├── AGENTS.md               # Codex behavioral and structural rules
│
└── README.md               # Public overview

------------------------------------------------------------
FOLDER RESPONSIBILITIES
------------------------------------------------------------

/core_shaders/

Purpose:
Contains pure GLSL only.

Rules:
- No platform-specific code
- No framework abstractions
- Must compile in raw GLSL sandbox
- Must not import from /platforms
- Shared logic goes in /includes

This folder must remain engine-pure.


/platforms/

Purpose:
Provide platform-specific GPU bindings and public APIs.

Rules:
- May reference or copy shader source from /core_shaders
- Must not define shader logic internally
- Must not depend on other platform folders
- Must expose clean framework-native APIs

Each platform must function independently when opened in VS Code.


/docs/

Purpose:
Define contracts, specs, and architectural decisions.

This folder documents:
- Uniform contract
- Naming conventions
- Public API design
- Roadmap
- Publishing strategy


/AGENTS.md/

Purpose:
Provide guardrails for automated tools (Codex).

Must enforce:
- Dependency direction rules
- Uniform naming conventions
- No platform leakage into core
- No structural drift

------------------------------------------------------------
UNIFORM CONTRACT (V1)
------------------------------------------------------------

All transition shaders must use standardized uniforms.

Required uniforms:

uniform float u_progress;
uniform vec2  u_resolution;

Optional standardized uniforms:

uniform float u_time;
uniform sampler2D u_texture0;
uniform sampler2D u_texture1;

Rules:
- Do not invent new uniform names casually.
- If a new uniform is required, update uniform_contract.md.
- Platforms must map these consistently.

------------------------------------------------------------
SHADER NAMING CONVENTION
------------------------------------------------------------

File naming:

morph_<descriptor>.frag
effect_<descriptor>.frag

Examples:

morph_basic.frag
morph_wave.frag
effect_noise.frag


Platform class naming:

MorphBasicTransition
MorphWaveTransition

Consistency prevents future refactors.

------------------------------------------------------------
DEVELOPMENT WORKFLOW
------------------------------------------------------------

1. Create shader in /core_shaders/transitions
2. Validate in GLSL sandbox
3. Lock uniform API
4. Commit to core
5. Integrate into a platform adapter
6. Expose via platform-native API

Core first. Platform second.

------------------------------------------------------------
VERSIONING STRATEGY
------------------------------------------------------------

Initial phase:
Single unified repo version.

Future option:
Split platforms into independently versioned packages if required.

The structure must support either path without refactoring.

------------------------------------------------------------
SCALABILITY REQUIREMENTS
------------------------------------------------------------

Adding a new platform must require:

- Creating a new folder under /platforms
- Implementing uniform bindings
- Importing shaders from core

It must NOT require:

- Modifying core shaders
- Modifying other platforms
- Restructuring the repo

If adding a platform requires structural change,
the architecture is incorrect.

------------------------------------------------------------
MENTAL MODEL
------------------------------------------------------------

Core = Engine
Platforms = Adapters
Applications = Consumers

Engine stability is priority.
Adapters translate.
Consumers remain unaware of internal structure.

------------------------------------------------------------
END OF PROJECT MAP
------------------------------------------------------------