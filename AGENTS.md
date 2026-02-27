# AGENTS.md
ShaderMorph – Automation Guardrails

This file defines structural and behavioral rules for automated agents
(Codex, code generators, refactoring tools, etc.).

These rules must not be violated.

------------------------------------------------------------
CORE ARCHITECTURE RULES
------------------------------------------------------------

1. core_shaders is the single source of truth.

2. No platform-specific logic is allowed inside /core_shaders.

3. Platforms depend on core.
   Core must never depend on platforms.

4. Platform folders must never depend on each other.

5. Adding a new platform must not require modifying:
   - Existing platforms
   - core_shaders structure

If structural modification is required, the architecture is incorrect.

------------------------------------------------------------
CORE SHADER RULES
------------------------------------------------------------

1. All shader files must compile in isolation in a raw GLSL sandbox.

2. Shared logic must live inside:
   /core_shaders/includes

3. Transitions must live inside:
   /core_shaders/transitions

4. Effects must live inside:
   /core_shaders/effects

5. Do not introduce framework-specific uniforms.

6. All shaders must follow the uniform contract (v1).

------------------------------------------------------------
UNIFORM CONTRACT (V1)
------------------------------------------------------------

Required uniforms:

uniform float u_progress;
uniform vec2  u_resolution;

Optional standardized uniforms:

uniform float u_time;
uniform sampler2D u_texture0;
uniform sampler2D u_texture1;

Rules:

- Do not introduce new uniform names without updating docs/uniform_contract.md.
- Do not rename existing uniforms casually.
- Uniform naming must remain consistent across all platforms.

------------------------------------------------------------
PLATFORM RULES
------------------------------------------------------------

1. Platform folders may:
   - Import or copy shaders from core_shaders
   - Map standardized uniforms
   - Provide framework-native APIs

2. Platform folders may NOT:
   - Define shader logic internally
   - Modify core shader files
   - Introduce alternate uniform naming

3. Platform shader assets must be treated as generated or synced content.
   They are not the source of truth.

------------------------------------------------------------
FILE NAMING RULES
------------------------------------------------------------

Shader files:

morph_<descriptor>.frag
effect_<descriptor>.frag

Examples:

morph_basic.frag
morph_wave.frag
effect_noise.frag

Platform wrapper classes:

MorphBasicTransition
MorphWaveTransition

Consistency is mandatory.

------------------------------------------------------------
DEVELOPMENT WORKFLOW RULES
------------------------------------------------------------

Correct order:

1. Create or modify shader in /core_shaders
2. Validate in GLSL sandbox
3. Lock uniform API
4. Sync or copy into platform
5. Integrate via platform adapter

Never develop shader logic directly inside platform folders.

------------------------------------------------------------
AUTOMATION RULES
------------------------------------------------------------

If introducing tooling:

- Tooling must not blur dependency direction.
- Generated files must never become the source of truth.
- Automation must be optional and reversible.

------------------------------------------------------------
SCALABILITY RULE
------------------------------------------------------------

The repository must support:

- Adding new platforms without restructuring.
- Publishing platforms independently in the future.
- Extracting core_shaders into its own repository if required.

If a change breaks these assumptions, it must be rejected.

------------------------------------------------------------
END OF AGENTS RULES
------------------------------------------------------------