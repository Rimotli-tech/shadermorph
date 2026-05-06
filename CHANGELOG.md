## Unreleased

- Added host-free declarative cross-route navigation with
  `ShaderMorphTag(pushTo: ...)`.
- `ShaderMorphTag` now works as the unified endpoint widget for both
  single-page and cross-route flows:
  - `role: ShaderMorphRole.origin`
  - `role: ShaderMorphRole.destination`
- `ShaderMorphHost` is required only for single-page `forwardByTag` and
  `reverseByTag`; cross-route tags register without a host.
- `ShaderMorph.push(...)` remains available for separate-trigger and advanced
  cross-route flows.
- Added manual animation policy controls:
  - `ShaderMorphPolicy.always()`
  - `ShaderMorphPolicy.disabled()`
  - `ShaderMorphPolicy.disabledOnWeb()`
  - Suppressed transitions instant-settle without shader load, capture, or
    overlay animation.
- Protocol-V2 is now the default renderer for both single-page and cross-route
  morph flows.
- Legacy V1 rendering remains available as an emergency fallback with
  `SHADERMORPH_FORCE_V1_RENDER=true`.
- Added optional V2 shadow-bind debug flag while V1 is forced:
  `SHADERMORPH_V2_SHADOW_BIND=true`.
- Deprecated compatibility flags are still accepted for one window, with runtime
  warnings:
  - `SHADERMORPH_V2_RENDER_SINGLE_PAGE`
  - `SHADERMORPH_V2_RENDER_CROSS_ROUTE`
- Clarified Protocol-V2 coordinate-space docs for Flutter RuntimeEffect logical
  shader space.
- Added publish metadata:
  - repository
  - homepage
  - issue tracker
  - pub topics
- Style API is frozen to one public style:
  `MorphShaderStyle.standard`.
- Non-standard shader styles remain internal until a future public style API is
  introduced.
- Regression and stability fixes:
  - single-page shader-unavailable fallback now instant-settles
  - cross-route destination first-frame flash suppression
  - V2 sampler binding for source/destination textures
  - logical shader-space alignment for Flutter RuntimeEffect
  - cross-route reverse/pop animation lifetime cleanup

## 0.0.1

- Initial package baseline release.
