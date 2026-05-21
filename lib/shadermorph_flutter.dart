// Public entrypoint for the ShaderMorph Flutter package.
//
// Exported APIs cover:
// - Single-page morph orchestration with ShaderMorphHost and ShaderMorphTag
// - Cross-route morph orchestration with ShaderMorph
// - Metadata, capture, and transition configuration types
export 'src/models.dart';
export 'src/metadata.dart';
export 'src/cross_route.dart';
export 'src/policy.dart';
export 'src/shape.dart';
export 'src/transition_config.dart';

export 'src/widgets/morph_host.dart';

// Advanced capture and uniform-packing utilities.
export 'src/tracker.dart';
export 'src/coordinator.dart';
