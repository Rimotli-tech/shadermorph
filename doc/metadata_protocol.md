# ShaderMorph Metadata Protocol

This document defines the exact metadata-to-uniform contract between the Flutter
framework layer and the morph shader engine. It is intended for maintainers and
contributors working on capture, packing, or shader internals.

## 0. Runtime Notes

- Current public orchestration animates one selected tag id per transition.
  The uniform layout supports up to 8 packed pairs for the shader engine.
- `ShaderMorphPolicy` can suppress animation before shader load/capture; this
  does not change the uniform contract.

## 1. Coordinate Space

### 1.1 Capture space

Geometry is captured from Flutter in logical pixels, because `RenderBox` APIs
report logical coordinates.

Each `MorphSnapshot` MUST retain the device pixel ratio used at capture time:

- `dpr = View.of(context).devicePixelRatio`
- `physical = logical * dpr`

Backends that operate in physical fragment coordinates MUST convert logical
rects and logical resolution to physical pixels before normalization.

### 1.2 Normalization

Each rect is normalized relative to the render target resolution used by the
shader for `FlutterFragCoord()` remapping:

- `u_resolution = vec2(width, height)`

Rect normalization:

- `xN = x / u_resolution.x`
- `yN = y / u_resolution.y`
- `wN = w / u_resolution.x`
- `hN = h / u_resolution.y`

Origin: top-left `(0, 0)`

Range: `[0..1]` (values may be slightly outside during overscroll; clamp in shader)

Important invariant: rects and `u_resolution` MUST be expressed in the same
coordinate basis before normalization. Scaling both rect and resolution by the
same DPR produces the same normalized rect, so the shader remains deterministic
as long as `FlutterFragCoord().xy / u_resolution` and the normalized rects share
one basis.

### 1.3 Flutter shader space

The current Flutter renderer draws the shader through `CustomPaint` and
`FragmentShader`. In that path, `FlutterFragCoord()` is aligned to the logical
canvas coordinate system used by the painter.

Therefore the Flutter renderer packs:

- `u_resolution = logical canvas size`
- rects normalized against the logical canvas size

This is intentional. Passing physical `u_resolution` to the current Flutter
shader path would make `FlutterFragCoord().xy / u_resolution` use a different
basis from the canvas geometry and can misalign the morph on high-DPR devices.

Physical-space packing remains the required form for any backend whose fragment
coordinates are physical pixels.

## 2. Pairing Protocol

### 2.1 Tag matching

Elements are paired by string id, similar to `Hero`:

- If an id exists on both screens, it forms a pair.
- If an id exists on only one side, it is ignored for that transition.

### 2.2 Ordering (Deterministic)

Pairs are sorted by id ascending (lexicographic) before packing. This ensures
stable pair ordering across builds and devices.

### 2.3 MAX_PAIRS

`MAX_PAIRS = 8`

If more than 8 matched ids exist:

- Take the first 8 after sorting.
- Drop the rest deterministically.

## 3. Uniform Contract (Shader-Level)

Shader uniforms:

- `u_progress`: float `(0..1)`
- `u_resolution`: vec2 `(shader coordinate basis; logical for Flutter RuntimeEffect,
  physical for physical-pixel backends)`
- `u_morphStyle`: int
- `u_pairCount`: int `(0..8)`
- `u_sourceRects[8]`: vec4 `(x, y, w, h)` normalized
- `u_targetRects[8]`: vec4 `(x, y, w, h)` normalized
- `u_sourceShapeData[8]`: vec4 `(type, radiusRatio, reserved0, reserved1)`
- `u_targetShapeData[8]`: vec4 `(type, radiusRatio, reserved0, reserved1)`

Shape data:

- `type = 0`: rectangle
- `type = 1`: rounded rectangle
- `type = 2`: circle
- `type = 3`: stadium/capsule
- `radiusRatio`: corner radius divided by the endpoint's minimum logical
  dimension, clamped to `[0..0.5]`

## 4. Flutter -> FragmentShader Float Packing (STRICT)

Flutter `FragmentShader` uses `setFloat(index, value)`. The uniform floats MUST
be written in this exact order:

Scalars:

- `0`: `u_resolution.x`
- `1`: `u_resolution.y`
- `2`: `u_progress`
- `3`: `u_pairCount` (as float)
- `4`: `u_morphStyle` (as float)

Source rects (`8 * vec4 = 32` floats), starting at index `5`:

- `5  + (i * 4) + 0`: `source[i].x`
- `5  + (i * 4) + 1`: `source[i].y`
- `5  + (i * 4) + 2`: `source[i].w`
- `5  + (i * 4) + 3`: `source[i].h`

Target rects (next 32 floats), starting at index `37`:

- `37 + (i * 4) + 0`: `target[i].x`
- `37 + (i * 4) + 1`: `target[i].y`
- `37 + (i * 4) + 2`: `target[i].w`
- `37 + (i * 4) + 3`: `target[i].h`

Source shape data (next 32 floats), starting at index `69`:

- `69 + (i * 4) + 0`: `sourceShape[i].type`
- `69 + (i * 4) + 1`: `sourceShape[i].radiusRatio`
- `69 + (i * 4) + 2`: `sourceShape[i].reserved0`
- `69 + (i * 4) + 3`: `sourceShape[i].reserved1`

Target shape data (next 32 floats), starting at index `101`:

- `101 + (i * 4) + 0`: `targetShape[i].type`
- `101 + (i * 4) + 1`: `targetShape[i].radiusRatio`
- `101 + (i * 4) + 2`: `targetShape[i].reserved0`
- `101 + (i * 4) + 3`: `targetShape[i].reserved1`

Zero fill:

- For `i >= u_pairCount`, set rects to `vec4(0, 0, 0, 0)`.
- For unset shape data, use rectangle data: `vec4(0, 0, 0, 0)`.

## 5. Shader Membership & Overlap Rule

A pixel is considered "inside" rect `R` if:

- `uv.x in [R.x, R.x + R.w]`
- `uv.y in [R.y, R.y + R.h]`

If multiple pairs overlap at a pixel:

- The shader MUST choose the lowest index pair and break immediately.

This guarantees determinism.

## 6. Safety & Clamping

Shader MUST:

- Guard against division by zero (if `w` or `h == 0`).
- Clamp local UV into `[0..1]` before sampling.
- Clamp UV into `[0..1]` for background sampling.
