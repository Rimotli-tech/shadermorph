# ShaderMorph Example App

This example demonstrates the current preferred ShaderMorph APIs:

- Single-page morphs with `ShaderMorphHost` and `ShaderMorphTag`.
- Host-free cross-route morphs with `ShaderMorphTag(pushTo: ...)`.
- Reverse route morphs with `ShaderMorph.reverseAndPop(...)`.
- Optional endpoint shape hints with `MorphShape` and the experimental
  `MorphShaderStyle.shapeAware` style.

## What This Example Covers

Single-page:

- `ShaderMorphHost`
- `ShaderMorphTag`
- `ShaderMorphHost.of(context).forwardByTag(...)`
- `ShaderMorphHost.of(context).reverseByTag(...)`
- `ShaderMorphTrigger.onTapForward`
- `ShaderMorphTrigger.onTapReverse`
- `MorphShape`

Cross-route:

- Source endpoint declared with `ShaderMorphTag(role: origin, pushTo: ...)`
- Destination endpoint declared with `ShaderMorphTag(role: destination, ...)`
- Back navigation through `ShaderMorph.reverseAndPop(...)`

Shape-aware development:

- Keep `MorphShaderStyle.standard` for the stable default transition.
- Try `MorphShaderStyle.shapeAware` with endpoint hints like
  `MorphShape.circle()` and `MorphShape.roundedRect(radius: ...)` when
  validating circle-to-card or card-to-avatar transitions.

## Run

```bash
flutter run
```

## Manual Validation Checklist

1. Single-page Host + Tags:

- Tap **Forward by tag**.
- Expect both endpoints to hide during the overlay animation.
- Expect the destination endpoint to remain visible at completion.
- Tap **Reverse by tag**.
- Expect both endpoints to hide during motion.
- Expect the origin endpoint to remain visible at completion.

2. Cross-route:

- Tap **Open Cross-Route Morph**.
- Expect no native route slide-in because `suppressTransition` defaults to
  `true`.
- Expect the destination endpoint not to flash before morph capture.
- Tap **Reverse and Pop**.
- Re-enter the destination and verify the flow still works.

3. Regression guard:

- No white route flicker during default cross-route flow.
- No destination first-frame flash.
- No static snapshot left on screen after completion.

## Notes

- The source and destination route endpoints use the same `ShaderMorphTag`
  widget as the single-page flow.
- `ShaderMorphHost` is required only for single-page `forwardByTag` and
  `reverseByTag`; cross-route `pushTo` works without a host.
- `ShaderMorph.push(...)` remains available for separate-trigger flows where the
  origin endpoint should not be tappable.
