## ShaderMorph Flutter

Event-driven GPU morph transitions for single-page and cross-route flows.

## Current API

Single-page:
- `ShaderMorphHost`
- `ShaderMorphTag`
- `ShaderMorphHost.of(context).forwardByTag(...)`
- `ShaderMorphHost.of(context).reverseByTag(...)`

Cross-route:
- `ShaderMorph.tag(...)`
- `ShaderMorph.push(...)`
- `ShaderMorph.reverseAndPop(...)`

Config:
- `MorphTransitionConfig`
- `MorphInterpolation`
- `MorphShaderStyle`
- `MorphShadowCapturePolicy`
- `BackPopMode`

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

Phase behavior:
- Initial: source visible, destination hidden.
- `forwardByTag(id)`: both endpoints hidden during overlay animation; destination visible on completion.
- `reverseByTag(id)`: both endpoints hidden during overlay animation; source visible on completion.

## Quickstart (Cross-Route)

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

Cross-route lifecycle notes:
- Use `ShaderMorph.push(...)` for deterministic orchestration.
- Keep `suppressTransition: true` unless route motion is intentional.
- Destination first-frame flash is suppressed while preserving capture-ready textures.

## Protocol-V2 Runtime

Protocol-V2 is the default for single-page and cross-route rendering.

Emergency fallback to V1:

```bash
flutter run --dart-define=SHADERMORPH_FORCE_V1_RENDER=true
```

Optional V2 shadow bind while V1 is forced:

```bash
flutter run \
  --dart-define=SHADERMORPH_FORCE_V1_RENDER=true \
  --dart-define=SHADERMORPH_V2_SHADOW_BIND=true
```

Deprecated compatibility flags (still accepted for one window, with runtime warnings):
- `SHADERMORPH_V2_RENDER_SINGLE_PAGE`
- `SHADERMORPH_V2_RENDER_CROSS_ROUTE`
