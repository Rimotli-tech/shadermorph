# ShaderMorph Project Map (Protocol-V2)

Status: Protocol-V2 is the default renderer. V1 remains as emergency fallback.

## Repository Structure

- `docs/metadata_protocol_v2.md`
- `platforms/shadermorph_flutter/`
  - `lib/shadermorph_flutter.dart`
  - `lib/src/widgets/morph_host.dart`
  - `lib/src/cross_route.dart`
  - `lib/src/models.dart`
  - `lib/src/models_v2.dart`
  - `lib/src/transition_config.dart`
  - `lib/src/runtime_config.dart`
  - `lib/src/coordinator.dart`
  - `lib/src/tracker.dart`
  - `shaders/shader_engine.frag`
  - `shaders/shader_engine_v2.frag`
  - `example/lib/main.dart`
  - `test/*.dart`

## Runtime Architecture

Entry API:
- `ShaderMorphHost` + `ShaderMorphTag` (single-page)
- `ShaderMorphHost.of(context).forwardByTag(...)`
- `ShaderMorphHost.of(context).reverseByTag(...)`
- `ShaderMorph.tag(...)`
- `ShaderMorph.push(...)`
- `ShaderMorph.reverseAndPop(...)`

Single-page path:
1. `ShaderMorphTag` registers endpoint keys under page-local `ShaderMorphHost`.
2. App triggers explicit morph by id via host controller.
3. Host captures source/destination snapshots via `MorphTracker`.
4. Host renders overlay morph while endpoints are hidden.
5. Completion phase:
   - forward -> destination visible
   - reverse -> source visible
6. `MorphCoordinator` builds V2 metadata and binds uniforms.

Cross-route path:
1. `ShaderMorph.tag(...)` registers route endpoints in `MorphTagRegistry`.
2. `ShaderMorph.push(...)` creates a route-scoped cross-route engine.
3. Push route defaults to no-slide (`suppressTransition: true`).
4. Engine handles anti-flash endpoint hiding and stable destination capture.
5. `ShaderMorph.reverseAndPop(...)` drives reverse morph and pops route.

Renderer selection:
- Default: V2 single-page and cross-route.
- Fallback: `SHADERMORPH_FORCE_V1_RENDER=true`.
- Optional V2 shadow bind while V1 forced: `SHADERMORPH_V2_SHADOW_BIND=true`.

## Public API Surface

Primary:
- `ShaderMorphHost`
- `ShaderMorphTag`
- `ShaderMorphHostController`
- `ShaderMorphRole`
- `ShaderMorphTrigger`
- `ShaderMorph`
- `CrossRouteMorphTag`
- `ShaderMorphCrossRouteEngine`
- `BackPopMode`
- `MorphTransitionConfig`, `MorphInterpolation`, `MorphShaderStyle`
- `ShaderMorph.tag(...)`, `ShaderMorph.push(...)`, `ShaderMorph.reverseAndPop(...)`

## Protocol Snapshot

V2 payload:
- Scalar floats: `5`
- Source rect floats: `32` (`8 * vec4`)
- Target rect floats: `32` (`8 * vec4`)
- Total packed floats: `69`

Determinism:
- Deterministic pair ordering before packing.
- Pair cap `8` with deterministic truncation.
- Shader overlap winner: lowest index first hit.

Reference:
- `docs/metadata_protocol_v2.md`
