# ShaderMorph Example App

This example demonstrates the current preferred DX facade and Protocol-V2 default runtime behavior.

## What This Example Covers

- Single-page morph with event-driven `ShaderMorph`.
- Cross-route morph orchestration with:
  - `ShaderMorph.tag(...)`
  - `ShaderMorph.push(...)`
  - `ShaderMorph.reverseAndPop(...)`
- Back behavior parity:
  - `BackPopMode.reverseThenPop`
  - `BackPopMode.immediatePopReset`

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

1. Single-page default (`BackPopMode.reverseThenPop`):
- Open Single-Page Morph Demo.
- Observe auto-forward.
- Tap app-bar back.
- Expect reverse first, then pop.

2. Single-page immediate pop reset:
- Set `backPopMode: BackPopMode.immediatePopReset`.
- Open demo and allow auto-forward.
- Tap app-bar back.
- Expect immediate pop without reverse.
- Re-open and verify forward still works.

3. Cross-route:
- Open Cross-Route Morph Demo.
- Tap Go To Destination (Auto Morph).
- Expect no visible route slide-in from right.
- Tap Reverse + Pop.
- Re-enter destination and verify flow still works.

4. Regression guard:
- No flicker/snap/static texture artifacts.

## Notes

- This example intentionally reflects the event-driven API as the primary usage path.
- Legacy controller-heavy APIs are deprecated and retained only for migration compatibility.
