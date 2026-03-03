## ShaderMorph Flutter

Controller-driven widget morphing between source and destination textures using
the package shader engine.

## Modes

- Single-page morph (existing): `ShaderMorph` + `ShaderMorphController`
- Cross-route morph (new, opt-in): `MorphTag` + `CrossRouteMorphController`

## Usage

```dart
final controller = ShaderMorphController();

ShaderMorph(
  controller: controller,
  source: const Text('Source'),
  destination: const Text('Destination'),
  duration: const Duration(milliseconds: 800),
);

// External trigger
await controller.forward();
await controller.reverse();
```

## Cross-Route Usage

```dart
final crossController = CrossRouteMorphController();

// Source page
MorphTag(id: 'card_tag', child: sourceCard);
await crossController.startToRoute(
  context: context,
  tagId: 'card_tag',
  route: buildMorphRoute(
    page: DestinationPage(),
    suppressTransition: true,
  ),
);

// Destination page
MorphTag(id: 'card_tag', child: destinationCard3);
await crossController.playForward(context: context, tagId: 'card_tag');
```

## Pop Interception

Use `ShaderMorphPopHandler` to reverse before page pop.

```dart
ShaderMorphPopHandler(
  controller: controller,
  backPopMode: BackPopMode.reverseThenPop, // default
  child: Scaffold(
    body: ...,
  ),
)
```

`backPopMode` options:
- `BackPopMode.reverseThenPop`: reverse first, then pop.
- `BackPopMode.immediatePopReset`: pop immediately and reset to source state.

For cross-route mode, use `CrossRouteMorphPopHandler`.

## Protocol-V2 Controlled Switches

Segmented V2 rollout uses compile-time flags (all default `false`):

- `SHADERMORPH_V2_SHADOW_BIND=true`
  - Binds V2 uniforms in shadow mode while keeping V1 render path active.
- `SHADERMORPH_V2_RENDER_SINGLE_PAGE=true`
  - Switches single-page `ShaderMorph` overlay rendering to V2 shader.
- `SHADERMORPH_V2_RENDER_CROSS_ROUTE=true`
  - Switches cross-route overlay rendering to V2 shader.

Example:

```bash
flutter run \
  --dart-define=SHADERMORPH_V2_SHADOW_BIND=true \
  --dart-define=SHADERMORPH_V2_RENDER_SINGLE_PAGE=true
```
