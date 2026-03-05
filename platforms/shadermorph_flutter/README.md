## ShaderMorph Flutter

Event-driven GPU morph transitions for single-page and cross-route flows.

## Current Scope

- DX simplification is the active workstream (unified, event-driven API).
- Protocol-V2 is the default renderer.
- Style expansion is in segmented rollout (L1 currently adds `liquid` only).

## Current API Priority

Primary path (recommended):
- `ShaderMorphHost`
- `ShaderMorphTag`
- `ShaderMorphHost.of(context).forwardByTag(...)`
- `ShaderMorphHost.of(context).reverseByTag(...)`
- `ShaderMorph.tag(...)`
- `ShaderMorph.push(...)`
- `ShaderMorph.reverseAndPop(...)`

Legacy path:
- Deprecated compatibility APIs remain temporarily for migration only.

## Quickstart (Single-Page)

```dart
ShaderMorphHost(
  duration: const Duration(milliseconds: 700),
  transitionConfig: const MorphTransitionConfig(
    interpolation: MorphInterpolation.easeInOut,
    shaderStyle: MorphShaderStyle.soft,
  ),
  child: Builder(
    builder: (context) {
      final host = ShaderMorphHost.of(context);
      return Column(
        children: [
          GestureDetector(
            onTap: () => host.forwardByTag('profilePic'),
            child: ShaderMorphTag(
              id: 'profilePic',
              role: ShaderMorphRole.source,
              child: const SourceAvatar(),
            ),
          ),
          const Spacer(),
          ShaderMorphTag(
            id: 'profilePic',
            role: ShaderMorphRole.destination,
            child: const DestinationAvatar(),
          ),
        ],
      );
    },
  ),
)
```

Optional tag-level trigger:

```dart
ShaderMorphTag(
  id: 'profilePic',
  role: ShaderMorphRole.source,
  trigger: ShaderMorphTrigger.onTapForward,
  child: const SourceAvatar(),
)
```

Host behavior:
- `ShaderMorphHost` owns animation lifecycle, snapshot capture, overlay rendering, and endpoint hide/unhide.
- During `forwardByTag(id)`, destination is hidden while the overlay morph runs, then restored.

### Legacy Single-Page API (Deprecated)

`ShaderMorph(source: ..., destination: ...)` and `ShaderMorphHandle` remain available in the migration window, but new single-page integrations should use host + tags.

### Legacy Trigger Modes

- `ShaderMorphTriggerMode.manual`
- `ShaderMorphTriggerMode.tapToggle`
- `ShaderMorphTriggerMode.tapForward`
- `ShaderMorphTriggerMode.tapReverse`
- `ShaderMorphTriggerMode.onBuildForward`

### Legacy Back Behavior

- `BackPopMode.reverseThenPop` (default)
- `BackPopMode.immediatePopReset`

## Quickstart (Cross-Route)

Tag both endpoints with the same `tagId`, then use `ShaderMorph.push`.

```dart
// Source page endpoint
ShaderMorph.tag(id: 'card_tag', child: sourceCard)

await ShaderMorph.push(
  context: context,
  tagId: 'card_tag',
  page: const DestinationPage(tagId: 'card_tag'),
  suppressTransition: true,
  transitionConfig: const MorphTransitionConfig(
    interpolation: MorphInterpolation.smoothStep,
    shaderStyle: MorphShaderStyle.soft,
  ),
);
```

```dart
// Destination page endpoint
ShaderMorph.tag(id: 'card_tag', child: destinationCard)

// Back action
await ShaderMorph.reverseAndPop(context, tagId: 'card_tag');
```

Cross-route lifecycle note:
- Prefer `ShaderMorph.push(...)` for orchestration so source capture, route push, and destination capture stay in one deterministic flow.
- Keep `suppressTransition: true` unless you intentionally want visible route motion.

## Transition Config

`MorphTransitionConfig` controls interpolation and style:

- Interpolation:
  - `MorphInterpolation.linear`
  - `MorphInterpolation.easeIn`
  - `MorphInterpolation.easeOut`
  - `MorphInterpolation.easeInOut`
  - `MorphInterpolation.smoothStep`
- Styles:
  - `MorphShaderStyle.classic`
  - `MorphShaderStyle.soft`
  - `MorphShaderStyle.ripple`
  - `MorphShaderStyle.liquid`

## Old -> New API Mapping

- `ShaderMorphController + await controller.forward()` -> `ShaderMorphHost.of(context).forwardByTag(id)` or explicit tag trigger
- `ShaderMorph(source:..., destination:...)` -> `ShaderMorphHost(child: ...)` + `ShaderMorphTag(role: ...)`
- `ShaderMorphPopHandler` -> built into `ShaderMorph(backPopMode: ...)`
- `CrossRouteMorphController.startToRoute(...)` -> `ShaderMorph.push(...)`
- `MorphTag(...)` -> `ShaderMorph.tag(...)`
- `controller.playReverseDuringPop(...)` -> `ShaderMorph.reverseAndPop(...)`

## Breaking-Change Migration Note

The event-driven facade is the primary API. Legacy controller-heavy APIs remain available only for the migration window and are deprecated.

## Protocol-V2 Runtime

Protocol-V2 is the default for single-page and cross-route rendering.

Emergency fallback to legacy V1 (temporary):

```bash
flutter run --dart-define=SHADERMORPH_FORCE_V1_RENDER=true
```

Optional V2 shadow bind while V1 fallback is active:

```bash
flutter run \
  --dart-define=SHADERMORPH_FORCE_V1_RENDER=true \
  --dart-define=SHADERMORPH_V2_SHADOW_BIND=true
```

Deprecated compatibility flags (still accepted for one window, with runtime warnings):
- `SHADERMORPH_V2_RENDER_SINGLE_PAGE`
- `SHADERMORPH_V2_RENDER_CROSS_ROUTE`
