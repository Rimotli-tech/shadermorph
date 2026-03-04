## Unreleased

- Protocol-V2 is now the default renderer for both single-page and cross-route morph flows.
- Added emergency fallback runtime flag: `SHADERMORPH_FORCE_V1_RENDER=true`.
- Added optional shadow-bind debug flag while V1 is forced: `SHADERMORPH_V2_SHADOW_BIND=true`.
- Added DX facade features:
  - `ShaderMorph` controller is optional (auto-owned when omitted).
  - Event-driven triggers via `ShaderMorphTriggerMode`.
  - `ShaderMorphHandle` for optional manual `forward/reverse/toggle`.
  - Unified helpers: `ShaderMorph.tag(...)`, `ShaderMorph.push(...)`, `ShaderMorph.reverseAndPop(...)`.
- Marked legacy controller-centric APIs as deprecated (migration window):
  - `ShaderMorphController`
  - `ShaderMorphPopHandler`
  - `CrossRouteMorphController`
  - `CrossRouteMorphPopHandler`
  - `MorphTag`
  - `buildMorphRoute(...)`
  - `ShaderMorphRouteBridge`
- Regression and stability fixes:
  - Fixed pop freeze paths across single-page modes.
  - Fixed V2 sampler binding (`source`/`destination` images) to avoid invalid shader usage.
  - Fixed logical shader-space alignment to prevent incorrect size/position rendering.
  - Fixed `childBuilder` recursion path that caused widget tree inflation crashes.
  - Fixed cross-route reverse+pop animation lifetime/controller disposal sequencing.

## 0.0.1

- Initial package baseline release.
