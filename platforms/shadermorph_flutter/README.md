## ShaderMorph Flutter

Event-driven GPU morph transitions for single-page and cross-route flows.

## Quickstart (Single-Page)

```dart
ShaderMorph(
  source: const SourceCard(),
  destination: const DestinationCard(),
  duration: const Duration(milliseconds: 700),
  triggerMode: ShaderMorphTriggerMode.onBuildForward,
  backPopMode: BackPopMode.reverseThenPop,
  transitionConfig: const MorphTransitionConfig(
    interpolation: MorphInterpolation.easeInOut,
    shaderStyle: MorphShaderStyle.soft,
  ),
  childBuilder: (context, morphChild) {
    final handle = ShaderMorphHandle.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        morphChild,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(onPressed: handle.forward, child: const Text('Forward')),
            ElevatedButton(onPressed: handle.reverse, child: const Text('Reverse')),
          ],
        ),
      ],
    );
  },
)
```

### Trigger Modes

- `ShaderMorphTriggerMode.manual`
- `ShaderMorphTriggerMode.tapToggle`
- `ShaderMorphTriggerMode.tapForward`
- `ShaderMorphTriggerMode.tapReverse`
- `ShaderMorphTriggerMode.onBuildForward`

### Back Behavior

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

## Old -> New API Mapping

- `ShaderMorphController + await controller.forward()` -> `triggerMode` or `ShaderMorphHandle.of(context).forward()`
- `ShaderMorphPopHandler` -> built into `ShaderMorph(backPopMode: ...)`
- `CrossRouteMorphController.startToRoute(...)` -> `ShaderMorph.push(...)`
- `MorphTag(...)` -> `ShaderMorph.tag(...)`
- `controller.playReverseDuringPop(...)` -> `ShaderMorph.reverseAndPop(...)`

## Legacy Compatibility

Controller-first and legacy cross-route internals remain available for one migration window,
but new development should use the event-driven API above.

## Protocol-V2 Runtime

Protocol-V2 is default for both single-page and cross-route rendering.

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
