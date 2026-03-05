# ShaderMorph Example App

This example demonstrates the current preferred DX facade and Protocol-V2 default runtime behavior.

## What This Example Covers

- Single-page tag-driven morph with:
  - `ShaderMorphHost`
  - `ShaderMorphTag`
  - `ShaderMorphHost.of(context).forwardByTag(...)`
  - `ShaderMorphHost.of(context).reverseByTag(...)`
- Cross-route morph orchestration with:
  - `ShaderMorph.tag(...)`
  - `ShaderMorph.push(...)`
  - `ShaderMorph.reverseAndPop(...)`
- Overlay-only transition behavior during active animation (endpoints hidden while shader renders).

## Run

```bash
flutter run
```

Optional fallback testing:

```bash
flutter run --dart-define=SHADERMORPH_FORCE_V1_RENDER=true
```

Optional shadow-bind debug while forced V1:

```bash
flutter run \
  --dart-define=SHADERMORPH_FORCE_V1_RENDER=true \
  --dart-define=SHADERMORPH_V2_SHADOW_BIND=true
```

## Manual Validation Checklist

1. Single-page Host + Tags:
- Tap **Forward by tag**.
- Expect source/destination endpoints to hide during motion, then destination visible at completion.
- Tap **Reverse by tag**.
- Expect endpoints to hide during motion, then source visible at completion.

2. Cross-route:
- Tap **Open Cross-Route Morph**.
- Expect no visible route slide-in from right.
- Ensure destination endpoint does not flash before morph.
- Tap **Reverse and Pop**.
- Re-enter destination and verify flow still works.

3. Regression guard:
- No flicker/snap/static texture artifacts.
- No destination first-frame flash on cross-route destination page.

## Notes

- This example intentionally reflects the event-driven API as the primary usage path.
- Legacy controller-heavy APIs are deprecated and retained only for migration compatibility.
