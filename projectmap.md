# ShaderMorph Project Map

Status: ShaderMorph is a tag-based shared element transition package for
same-page and cross-route morph animations.

## Repository Structure

- `lib/shadermorph_flutter.dart` - public package exports.
- `lib/src/widgets/morph_host.dart` - single-page host, unified tag widget,
  static `ShaderMorph` cross-route facade, and painters.
- `lib/src/cross_route.dart` - cross-route registry, session store, and engine.
- `lib/src/policy.dart` - manual animation allow/suppress policy.
- `lib/src/models.dart` and `lib/src/models_v2.dart` - snapshots and metadata.
- `lib/src/coordinator.dart` - uniform binding and metadata packing.
- `lib/src/tracker.dart` - widget capture, capture layers, and normalization.
- `lib/src/runtime_config.dart` - runtime environment switches.
- `lib/src/shader_program_cache.dart` - shared shader program cache.
- `shaders/` - fragment shaders.
- `doc/metadata_protocol_v2.md` - low-level shader metadata contract.
- `example/lib/main.dart` - current preferred API demo.
- `test/*.dart` - API, metadata, policy, registry, and visual regression tests.

## Runtime Architecture

Entry APIs:

- `ShaderMorphHost` + `ShaderMorphTag` for single-page transitions.
- `ShaderMorphTag(pushTo: ...)` for host-free declarative cross-route pushes.
- `ShaderMorph.push(...)` for separate-trigger or advanced cross-route flows.
- `ShaderMorph.reverseAndPop(...)` for reverse cross-route pop.
- `ShaderMorph.tag(...)` and `CrossRouteMorphTag` remain available as low-level
  cross-route tag wrappers.

Single-page path:

1. `ShaderMorphTag` registers endpoint keys under a page-local
   `ShaderMorphHost` when one exists.
2. App triggers a morph via `ShaderMorphHost.of(context).forwardByTag(...)`,
   `reverseByTag(...)`, or `ShaderMorphTrigger`.
3. The host validates exactly one mounted origin and destination for the id.
4. `ShaderMorphPolicy` may instant-settle before shader load/capture.
5. `MorphTracker` captures origin/destination snapshots.
6. The host hides both real endpoints and renders a shader overlay.
7. Completion lands destination-visible for forward and origin-visible for
   reverse.
8. `MorphCoordinator` builds metadata and binds uniforms for each frame.

Cross-route path:

1. `ShaderMorphTag` always registers with `MorphTagRegistry`, so route morphs do
   not require `ShaderMorphHost`.
2. For common tap-to-route flows, `ShaderMorphTag(pushTo: page)` calls
   `ShaderMorph.push(...)` internally.
3. For separate trigger widgets, apps can call `ShaderMorph.push(...)` directly
   with a matching tag id.
4. The engine captures the origin before push, hides same-id endpoints, waits for
   the destination tag to mount and stabilize, then captures destination.
5. A root overlay renders the source-to-destination morph.
6. `ShaderMorph.reverseAndPop(...)` captures the current destination, pops the
   route, and morphs back to the stored origin snapshot.
7. If policy suppresses animation, the route/state instant-settles without
   shader load, capture, or overlay animation.

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
- `MorphShadowCapturePolicy`
- `ShaderMorphPolicy`, `ShaderMorphPolicyMode`

Main flows:

- Single-page: `ShaderMorphHost` + `ShaderMorphTag`.
- Declarative cross-route: `ShaderMorphTag(pushTo: ...)`.
- Separate-trigger cross-route: `ShaderMorph.push(...)`.
- Reverse route pop: `ShaderMorph.reverseAndPop(...)`.

## Design Principles

- Widgets define intent through shared ids and roles.
- Shaders receive state only through captured textures, rects, progress, and
  style uniforms.
- Flutter owns tagging, capture, navigation, lifecycle, and policy decisions.
- The common path should be declarative; lower-level APIs remain available for
  custom trigger and navigation flows.
- The public style surface is intentionally small: `MorphShaderStyle.standard`.
