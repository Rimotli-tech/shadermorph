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
  route: MaterialPageRoute<void>(builder: (_) => DestinationPage()),
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
  child: Scaffold(
    body: ...,
  ),
)
```

The pop handler attempts `reverse()` when the morph is at destination state,
waits for completion, and then allows pop.

For cross-route mode, use `CrossRouteMorphPopHandler`.
