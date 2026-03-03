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

## Protocol-V2 Runtime

Protocol-V2 is now the default render path for both single-page and cross-route.

### Emergency fallback (temporary compatibility window)

Use this only if you need to force legacy V1 rendering:

```bash
flutter run --dart-define=SHADERMORPH_FORCE_V1_RENDER=true
```

Optional debug mode while V1 fallback is active:

```bash
flutter run \
  --dart-define=SHADERMORPH_FORCE_V1_RENDER=true \
  --dart-define=SHADERMORPH_V2_SHADOW_BIND=true
```

### Deprecated flags (one-cycle compatibility)

- `SHADERMORPH_V2_RENDER_SINGLE_PAGE`
- `SHADERMORPH_V2_RENDER_CROSS_ROUTE`

These are deprecated and mapped for compatibility. Prefer `SHADERMORPH_FORCE_V1_RENDER`.
