# ShaderMorph Flutter

`shadermorph_flutter` is a Flutter package for **shared element transitions and
morph animations between widgets**, including cross-route navigation
transitions.

It is an advanced alternative to Flutter's built-in Hero animation, enabling:

- Morphing shapes, not just position and scale
- Smooth GPU-driven animations
- Cross-route shared element transitions
- Tag-based pairing of origin and destination widgets
- Manual performance policies for platforms where animation should instant-settle

## Mental Model

- A morph is defined by two widgets sharing the same `id`.
- One widget is the `origin`, the other is the `destination`.
- ShaderMorph captures both endpoints and animates between them.
- Same-page transitions use `ShaderMorphHost`.
- Navigation transitions use `ShaderMorphTag(pushTo: ...)` or
  `ShaderMorph.push(...)`.

## Installation

```yaml
dependencies:
  shadermorph_flutter: ^0.0.1
```

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
- `forwardByTag(id)`: both endpoints hide during animation, then destination
  remains visible.
- `reverseByTag(id)`: both endpoints hide during animation, then origin remains
  visible.

## Quickstart: Cross-Route

```dart
// Source page
ShaderMorphTag(
  id: 'card_tag',
  role: ShaderMorphRole.origin,
  pushTo: const DestinationPage(tagId: 'card_tag'),
  transitionConfig: const MorphTransitionConfig(
    interpolation: MorphInterpolation.easeInOut,
    shaderStyle: MorphShaderStyle.standard,
  ),
  child: sourceCard,
)
```

```dart
// Destination page
ShaderMorphTag(
  id: 'card_tag',
  role: ShaderMorphRole.destination,
  child: destinationCard,
)

// Back navigation
await ShaderMorph.reverseAndPop(context, tagId: 'card_tag');
```

Notes:

- `ShaderMorphHost` is not required for cross-route transitions.
- `pushTo` is the preferred API for tap-driven navigation.
- Use `ShaderMorph.push(...)` for external triggers, menu actions, keyboard
  shortcuts, or any case where the origin itself should not be tappable.
- Native route transitions are suppressed by default for visual continuity.
- Destination first-frame flash is automatically prevented.

External trigger example:

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

## Core API

Single-page:

- `ShaderMorphHost`
- `ShaderMorphTag`
- `ShaderMorphHost.of(context).forwardByTag(...)`
- `ShaderMorphHost.of(context).reverseByTag(...)`

Cross-route:

- `ShaderMorphTag(pushTo: ...)`
- `ShaderMorph.push(...)`
- `ShaderMorph.reverseAndPop(...)`

Configuration:

- `MorphTransitionConfig`
- `MorphInterpolation`
- `MorphShaderStyle`
- `MorphShadowCapturePolicy`
- `ShaderMorphPolicy`
- `BackPopMode`

## Performance Policy

ShaderMorph can be conditionally disabled for performance-sensitive contexts.
Suppressed transitions instant-settle without shader animation.

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

Policy options:

- `ShaderMorphPolicy.always()` - default behavior
- `ShaderMorphPolicy.disabled()` - instant state change, no animation
- `ShaderMorphPolicy.disabledOnWeb()` - disables animations on web only

## Platform Notes

- Requires Flutter shader support.
- Geometry is captured in logical pixels and normalized for rendering.
- Designed to remain visually consistent across device pixel ratios.
- Web can be handled conservatively with `ShaderMorphPolicy.disabledOnWeb()`.

## Additional Documentation

- Full working example: [`example/lib/main.dart`](example/lib/main.dart)
- Example notes: [`example/README.md`](example/README.md)
- Architecture map: [`projectmap.md`](projectmap.md)

## Summary

ShaderMorph provides a clean, tag-based system for building high-quality shared
element transitions, morphing UI animations, and cross-route visual continuity
without the limitations of traditional Hero-based approaches.
