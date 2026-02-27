# ShaderMorph Metadata Protocol (V2 — Deterministic Morph Protocol)

This document defines the *exact* metadata-to-uniform contract between the Flutter framework layer
and the unified morph shader engine.

## 1. Coordinate Space (NON-NEGOTIABLE)

### 1.1 Physical pixels
All geometry extracted from Flutter MUST be expressed in **physical pixel space** before
normalization.

- RenderBox APIs provide logical pixels.
- Convert using:
  - dpr = View.of(context).devicePixelRatio
  - physical = logical * dpr

### 1.2 Normalization
Each rect is normalized relative to the full render target resolution in physical pixels:

- u_resolution = vec2(width_px, height_px)

Rect normalization:
- xN = x_px / u_resolution.x
- yN = y_px / u_resolution.y
- wN = w_px / u_resolution.x
- hN = h_px / u_resolution.y

Origin: top-left (0,0)
Range: [0..1] (values may be slightly outside during overscroll; clamp in shader)

## 2. Pairing Protocol

### 2.1 Tag matching
Elements are paired by String id (like Hero):
- If an id exists on both screens: it forms a pair
- If an id exists on only one side: it is ignored for that transition

### 2.2 Ordering (Deterministic)
Pairs are sorted by id ascending (lexicographic) before packing.
This ensures stable pair ordering across builds/devices.

### 2.3 MAX_PAIRS
MAX_PAIRS = 8
If more than 8 matched ids exist:
- take the first 8 after sorting
- drop the rest deterministically

## 3. Uniform Contract (Shader-Level)

Shader uniforms:

- u_progress: float (0..1)
- u_resolution: vec2 (physical pixels)
- u_morphStyle: int
- u_pairCount: int (0..8)
- u_sourceRects[8]: vec4(x,y,w,h) normalized
- u_targetRects[8]: vec4(x,y,w,h) normalized

## 4. Flutter → FragmentShader Float Packing (STRICT)

Flutter FragmentShader uses setFloat(index, value). The uniform floats MUST be written
in this exact order:

Scalars:
0: u_resolution.x
1: u_resolution.y
2: u_progress
3: u_pairCount (as float)
4: u_morphStyle (as float)

Source rects (8 * vec4 = 32 floats), starting at index 5:
5  + (i*4) + 0: source[i].x
5  + (i*4) + 1: source[i].y
5  + (i*4) + 2: source[i].w
5  + (i*4) + 3: source[i].h

Target rects (next 32 floats), starting at index 37:
37 + (i*4) + 0: target[i].x
37 + (i*4) + 1: target[i].y
37 + (i*4) + 2: target[i].w
37 + (i*4) + 3: target[i].h

Zero fill:
- For i >= u_pairCount: set rects to vec4(0,0,0,0)

## 5. Shader Membership & Overlap Rule

A pixel is considered "inside" rect R if:
- uv.x in [R.x, R.x + R.w] and uv.y in [R.y, R.y + R.h]

If multiple pairs overlap at a pixel:
- The shader MUST choose the **lowest index** pair and break immediately.
This guarantees determinism.

## 6. Safety & Clamping

Shader MUST:
- guard against division by zero (if w or h == 0)
- clamp local UV into [0..1] before sampling
- clamp uv into [0..1] for background sampling