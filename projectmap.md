# ShaderMorph Project Map (Protocol-V2 + DX Facade)

Status: Protocol-V2 is the default renderer. V1 is retained only as a temporary emergency fallback.

## Repository Structure (Current)

- `docs/metadata_protocol_v2.md`
- `platforms/shadermorph_flutter/`
  - `lib/shadermorph_flutter.dart`
  - `lib/src/widgets/morph_host.dart`
  - `lib/src/cross_route.dart`
  - `lib/src/navigation.dart`
  - `lib/src/controller.dart`
  - `lib/src/transition_config.dart`
  - `lib/src/runtime_config.dart`
  - `lib/src/coordinator.dart`
  - `lib/src/tracker.dart`
  - `lib/src/models.dart`
  - `lib/src/models_v2.dart`
  - `shaders/shader_engine.frag`
  - `shaders/shader_engine_v2.frag`
  - `example/lib/main.dart`
  - `test/*.dart`

## Runtime Architecture Map

Entry API:
- `ShaderMorphHost` + `ShaderMorphTag` (single-page primary)
- `ShaderMorphHost.of(context).forwardByTag(...)`
- `ShaderMorphHost.of(context).reverseByTag(...)`
- `ShaderMorph` (single-page legacy compatibility)
- `ShaderMorph.tag(...)`
- `ShaderMorph.push(...)`
- `ShaderMorph.reverseAndPop(...)`
- `ShaderMorphHandle.of(context)` for optional manual control

Single-page path:
1. `ShaderMorphTag` registers endpoint geometry keys with page-local `ShaderMorphHost`.
2. App triggers explicit morph by id via `forwardByTag` / `reverseByTag`.
3. `ShaderMorphHost` captures source/destination snapshots via `MorphTracker`.
4. Host hides target endpoint during active overlay morph and restores visibility after.
5. `MorphCoordinator` builds metadata and writes uniforms.
6. V2 shader (`shader_engine_v2.frag`) renders by default.
7. Legacy `ShaderMorph` path remains during compatibility window.

Cross-route path:
1. `ShaderMorph.tag(...)` marks endpoints (`MorphTag` internal legacy type).
2. `ShaderMorph.push(...)` creates and owns a route-scoped controller.
3. Push route uses no-slide behavior by default (`suppressTransition: true`).
4. `ShaderMorph.reverseAndPop(...)` drives reverse morph then pops.

Renderer selection:
- Default: V2 for single-page and cross-route.
- Emergency fallback: force V1 with `SHADERMORPH_FORCE_V1_RENDER=true`.
- Optional shadow-bind debug when V1 forced: `SHADERMORPH_V2_SHADOW_BIND=true`.

## Public API Surface

Primary (recommended):
- `ShaderMorphHost`
- `ShaderMorphTag`
- `ShaderMorphHostController`
- `ShaderMorphRole`
- `ShaderMorphTrigger`
- `ShaderMorphTriggerMode`
- `ShaderMorphEvent` / `ShaderMorphEventType`
- `ShaderMorphHandle`
- `BackPopMode`
- `MorphTransitionConfig`, `MorphInterpolation`, `MorphShaderStyle`
- `ShaderMorph.tag(...)`, `ShaderMorph.push(...)`, `ShaderMorph.reverseAndPop(...)`

Legacy (deprecated compatibility window):
- `ShaderMorphController`
- `ShaderMorphPopHandler`
- `CrossRouteMorphController`
- `CrossRouteMorphPopHandler`
- `MorphTag`
- `buildMorphRoute(...)`
- `ShaderMorphRouteBridge`

## Protocol Contract Snapshot

Protocol-V2 payload shape:
- Scalar float count: `5`
- Source rect floats: `32` (`8 * vec4`)
- Target rect floats: `32` (`8 * vec4`)
- Total packed float count: `69`

Determinism requirements:
- Deterministic pair ordering before packing.
- Pair cap of `8` with deterministic truncation.
- Overlap winner in shader is lowest index, first hit.

Authoritative packing reference:
- `docs/metadata_protocol_v2.md`

Runtime flags:
- `SHADERMORPH_FORCE_V1_RENDER`
- `SHADERMORPH_V2_SHADOW_BIND`
- Deprecated aliases (compatibility window):
  - `SHADERMORPH_V2_RENDER_SINGLE_PAGE`
  - `SHADERMORPH_V2_RENDER_CROSS_ROUTE`

## Migration State

DX facade migration is the current primary usage model.
Controller-first APIs remain temporarily as deprecated compatibility shims and are planned for removal after the migration window.
