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
- Added publish metadata:
  - repository
  - homepage
  - issue tracker
  - pub topics
- Style API is currently focused on `MorphShaderStyle.standard`.
- Regression and stability fixes:
  - shader-unavailable single-page transitions now instant-settle
  - cross-route destination first-frame flash suppression
  - source/destination texture binding fixes
  - logical shader-space alignment across device pixel ratios
  - cross-route reverse/pop animation lifetime cleanup

## 0.0.1

- Initial package baseline release.
