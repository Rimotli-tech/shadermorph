## ShaderMorph Flutter

Controller-driven widget morphing between source and destination textures using
the package shader engine.

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
