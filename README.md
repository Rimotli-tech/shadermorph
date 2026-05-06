# ShaderMorph Flutter

`shadermorph_flutter` provides GPU-driven morph transitions for Flutter widgets.
It supports both:

- Single-page transitions coordinated by `ShaderMorphHost`
- Cross-route transitions coordinated by `ShaderMorphTag(pushTo: ...)` or
  `ShaderMorph.push(...)`

The package is built around deterministic geometry capture. Rects are collected in
Flutter, packed into uniforms, and consumed by a shader that stays "dumb" about UI state.

## Installation

```yaml
dependencies:
  shadermorph_flutter: ^0.0.1
```

## Platform Notes

- Requires Flutter shader support.
- Ships both a Protocol-V2 render path and a temporary V1 fallback path.
- Geometry is captured in logical pixels and retains the capture DPR.
- The Flutter `RuntimeEffect` renderer normalizes rects against the logical
  shader canvas because `FlutterFragCoord()` is logical in this render path.
- Physical-pixel normalization remains the protocol target for backends whose
  fragment coordinates are physical pixels.

## Public API

Single-page:

- `ShaderMorphHost`
- `ShaderMorphTag`
- `ShaderMorphHost.of(context).forwardByTag(...)`
- `ShaderMorphHost.of(context).reverseByTag(...)`

Cross-route:

- `ShaderMorphTag(pushTo: ...)`
- `ShaderMorph.tag(...)`
- `ShaderMorph.push(...)`
- `ShaderMorph.reverseAndPop(...)`

Configuration:

- `MorphTransitionConfig`
- `MorphInterpolation`
- `MorphShaderStyle`
- `MorphShadowCapturePolicy`
- `ShaderMorphPolicy`
- `ShaderMorphPolicyMode`
- `BackPopMode`

## Quickstart: Single-Page

```dart
import 'package:shadermorph_flutter/shadermorph_flutter.dart';

ShaderMorphHost(
  duration: const Duration(milliseconds: 700),
  transitionConfig: const MorphTransitionConfig(
    interpolation: MorphInterpolation.easeInOut,
    shaderStyle: MorphShaderStyle.standard,
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
              role: ShaderMorphRole.origin,
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
  role: ShaderMorphRole.origin,
  trigger: ShaderMorphTrigger.onTapForward,
  child: const SourceAvatar(),
)
```

Behavior:

- Initial: origin visible, destination hidden.
- `forwardByTag(id)`: both endpoints hidden during overlay animation;
  destination visible on completion.
- `reverseByTag(id)`: both endpoints hidden during overlay animation; origin
  visible on completion.

## Quickstart: Cross-Route

```dart
import 'package:shadermorph_flutter/shadermorph_flutter.dart';

// Source page endpoint
ShaderMorphTag(
  id: 'card_tag',
  role: ShaderMorphRole.origin,
  pushTo: const DestinationPage(tagId: 'card_tag'),
  transitionConfig: const MorphTransitionConfig(
    interpolation: MorphInterpolation.smoothStep,
    shaderStyle: MorphShaderStyle.standard,
  ),
  child: sourceCard,
)
```

```dart
// Destination page endpoint
ShaderMorphTag(
  id: 'card_tag',
  role: ShaderMorphRole.destination,
  child: destinationCard,
)

// Back action
await ShaderMorph.reverseAndPop(context, tagId: 'card_tag');
```

Cross-route notes:

- Use `ShaderMorphTag(pushTo: ...)` for the common tap-to-route flow.
- Use `ShaderMorph.push(...)` when a separate widget should trigger the route.
- `ShaderMorphHost` is not required for cross-route morphs.
- Keep `suppressTransition: true` unless route motion is intentional.
- Destination first-frame flash is suppressed while preserving capture-ready textures.

Separate trigger example:

```dart
ShaderMorphTag(
  id: 'card_tag',
  role: ShaderMorphRole.origin,
  child: sourceCard,
)

IconButton(
  icon: const Icon(Icons.open_in_new),
  onPressed: () {
    ShaderMorph.push(
      context: context,
      tagId: 'card_tag',
      page: const DestinationPage(tagId: 'card_tag'),
    );
  },
)
```

## Performance Policy

ShaderMorph animations can be manually suppressed when an app wants instant
state changes on specific platforms or device classes.

```dart
ShaderMorphHost(
  policy: const ShaderMorphPolicy.disabledOnWeb(),
  child: child,
)
```

```dart
ShaderMorphTag(
  id: 'card_tag',
  role: ShaderMorphRole.origin,
  pushTo: const DestinationPage(tagId: 'card_tag'),
  policy: const ShaderMorphPolicy.disabled(),
  child: sourceCard,
)
```

Policies:
- `ShaderMorphPolicy.always()`: default, keep shader morphs enabled.
- `ShaderMorphPolicy.disabled()`: skip shader/capture work and instant-settle.
- `ShaderMorphPolicy.disabledOnWeb()`: instant-settle on web, animate elsewhere.

## Runtime Flags

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

## Additional Documentation

- Protocol details: [`doc/metadata_protocol_v2.md`](doc/metadata_protocol_v2.md)
- Working example: [`example/lib/main.dart`](example/lib/main.dart)
