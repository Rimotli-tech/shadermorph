# AGENTS.md — Protocol Guardrails

## 1. DETERMINISM RULE
Shaders must be "Dumb." They are prohibited from calculating UI state. 
All position, scale, and rotation data MUST come from the `u_sourceRects` and `u_targetRects` uniforms.

## 2. GEOMETRY ABSTRACTION
No shader code should reference hardcoded pixel values. 
Coordinate math must be performed using the remapping logic: 
SourceRect -> TargetRect interpolation based on u_progress.

## 3. PLATFORM RESPONSIBILITY
The Platform layer is responsible for:
- Identifying "Tagged" elements.
- Capturing 'Before' and 'After' geometry.
- Normalizing coordinates relative to the screen resolution.
- Managing the lifecycle of the MorphStyle selection.

## 4. MODULARITY
New visual effects should be implemented as "Styles" within the modular GLSL engine, not as standalone transition files. 
Each Style must support N-number of morphing pairs.

## 5. PERFORMANCE
The Framework must minimize the number of uniforms passed per frame. 
If no geometry changes, the Framework must not trigger a metadata re-sync.

## 6. COORDINATE SPACE + DPR RULE (V2)
All metadata MUST be extracted in logical pixels then converted to physical pixels using
devicePixelRatio before normalization against u_resolution.

## 7. UNIFORM PACKING RULE (V2)
The Flutter adapter MUST pack floats in the exact order specified by docs/metadata_protocol_v2.md.
Any deviation is considered a protocol break.