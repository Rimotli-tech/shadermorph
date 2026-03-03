import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../models.dart';
import '../tracker.dart';
import '../coordinator.dart';
import '../controller.dart';
import '../runtime_config.dart';
import '../transition_config.dart';

class ShaderMorph extends StatefulWidget {
  final Widget source;
  final Widget destination;
  final Duration duration;
  final ShaderMorphController controller;
  final MorphTransitionConfig transitionConfig;

  const ShaderMorph({
    super.key,
    required this.source,
    required this.destination,
    required this.controller,
    this.duration = const Duration(milliseconds: 800),
    this.transitionConfig = const MorphTransitionConfig(),
  });

  @override
  State<ShaderMorph> createState() => _ShaderMorphState();
}

class _ShaderMorphState extends State<ShaderMorph>
    with SingleTickerProviderStateMixin
    implements ShaderMorphPlaybackDelegate {
  final GlobalKey _sourcePaintKey = GlobalKey();
  final GlobalKey _destinationPaintKey = GlobalKey();
  late AnimationController _controller;

  MorphPairSnapshot? _snapshot;
  ui.FragmentProgram? _program;
  // Deprecated emergency fallback path. Remove after V2 stabilization window.
  ui.FragmentProgram? _v1Program;
  ui.FragmentShader? _v2ShadowShader;
  ui.FragmentShader? _v2RenderShader;
  MorphDirection _activeDirection = MorphDirection.forward;
  MorphPlaybackState _playbackState = MorphPlaybackState.idleSource;
  bool _sourceVisible = true;
  bool _destinationVisible = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _completeMorph();
        }
      });
    widget.controller.attach(this);
    widget.controller.setStateFromHost(_playbackState);
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final v1Prog = await ui.FragmentProgram.fromAsset(
        'packages/shadermorph_flutter/shaders/shader_engine.frag',
      );
      ui.FragmentProgram? v2Prog;
      try {
        v2Prog = await ui.FragmentProgram.fromAsset(
          'packages/shadermorph_flutter/shaders/shader_engine_v2.frag',
        );
      } catch (_) {
        // Keep rendering available via V1 fallback if V2 cannot load.
      }

      final config = MorphRuntimeConfig.current;
      maybeLogRuntimeDeprecations(config);

      ui.FragmentShader? shadowShader;
      if (config.enableV2ShadowBindWhenV1 && v2Prog != null) {
        shadowShader = v2Prog.fragmentShader();
      }
      final renderShader = config.useV2SinglePageRender && v2Prog != null
          ? v2Prog.fragmentShader()
          : null;

      final activeProgram = v2Prog ?? v1Prog;
      if (mounted) setState(() => _program = activeProgram);
      _v1Program = v1Prog;
      _v2ShadowShader = shadowShader;
      _v2RenderShader = renderShader;
    } catch (e) {
      debugPrint('ShaderMorph: Failed to load shader.');
    }
  }

  @override
  void didUpdateWidget(covariant ShaderMorph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.detach(this);
      widget.controller.attach(this);
      widget.controller.setStateFromHost(_playbackState);
    }
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  Future<bool> play({required MorphDirection direction}) async {
    if (_program == null) return false;
    if (_isAnimating) return false;
    if (!_canPlay(direction)) return false;

    _activeDirection = direction;
    final data = await MorphTracker.capturePair(
      sourceKey: direction == MorphDirection.forward
          ? _sourcePaintKey
          : _destinationPaintKey,
      destinationKey: direction == MorphDirection.forward
          ? _destinationPaintKey
          : _sourcePaintKey,
    );

    if (!mounted) return false;

    setState(() {
      _snapshot = data;
      _playbackState = direction == MorphDirection.forward
          ? MorphPlaybackState.animatingForward
          : MorphPlaybackState.animatingReverse;
      _sourceVisible = false;
      _destinationVisible = false;
    });
    widget.controller.setStateFromHost(_playbackState);

    _showOverlay();
    await _controller.forward(from: 0.0);
    return true;
  }

  void _showOverlay() {
    if (_snapshot == null || _program == null) return;

    final overlayState = Overlay.of(context);
    final config = MorphRuntimeConfig.current;
    final v1Shader = _v1Program?.fragmentShader();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _InternalMorphPainter(
                  shader: _program!.fragmentShader(),
                  v1Shader: v1Shader,
                  v2ShadowShader: _v2ShadowShader,
                  v2RenderShader: _v2RenderShader,
                  useV2Render: config.useV2SinglePageRender,
                  transitionConfig: widget.transitionConfig,
                  snapshot: _snapshot!,
                  time: _controller.value * 6.28,
                  progress: _controller.value,
                ),
              );
            },
          ),
        ),
      ),
    );

    overlayState.insert(_overlayEntry!);
  }

  bool get _isAnimating =>
      _playbackState == MorphPlaybackState.animatingForward ||
      _playbackState == MorphPlaybackState.animatingReverse;

  bool _canPlay(MorphDirection direction) {
    if (direction == MorphDirection.forward) {
      return _playbackState == MorphPlaybackState.idleSource;
    }
    return _playbackState == MorphPlaybackState.idleDestination;
  }

  void _completeMorph() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() {
        _snapshot = null;
        if (_activeDirection == MorphDirection.forward) {
          _playbackState = MorphPlaybackState.idleDestination;
          _sourceVisible = false;
          _destinationVisible = true;
        } else {
          _playbackState = MorphPlaybackState.idleSource;
          _sourceVisible = true;
          _destinationVisible = false;
        }
      });
      widget.controller.setStateFromHost(_playbackState);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: _destinationVisible ? 1.0 : 0.01,
          child: RepaintBoundary(
            key: _destinationPaintKey,
            child: widget.destination,
          ),
        ),
        const Divider(height: 50),
        Opacity(
          opacity: _sourceVisible ? 1.0 : 0.0,
          child: RepaintBoundary(key: _sourcePaintKey, child: widget.source),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    widget.controller.detach(this);
    widget.controller.setStateFromHost(MorphPlaybackState.disposed);
    _controller.dispose();
    super.dispose();
  }
}

class _InternalMorphPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ui.FragmentShader? v1Shader;
  final ui.FragmentShader? v2ShadowShader;
  final ui.FragmentShader? v2RenderShader;
  final bool useV2Render;
  final MorphTransitionConfig transitionConfig;
  final MorphPairSnapshot snapshot;
  final double time;
  final double progress;

  _InternalMorphPainter({
    required this.shader,
    required this.v1Shader,
    required this.v2ShadowShader,
    required this.v2RenderShader,
    required this.useV2Render,
    required this.transitionConfig,
    required this.snapshot,
    required this.time,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shapedProgress = transitionConfig.transformProgress(progress);
    final metadata = MorphCoordinator.buildSinglePairMetadataV2(
      logicalViewport: size,
      sourceRect: snapshot.source,
      targetRect: snapshot.destination,
      progress: shapedProgress,
      morphStyle: transitionConfig.shaderStyleIndex,
      // RuntimeEffect fragment coordinates are logical-canvas space.
      usePhysicalResolution: false,
    );

    if (v2ShadowShader != null) {
      MorphCoordinator.setUniformsV2Packed(
        shader: v2ShadowShader!,
        metadata: metadata,
      );
      v2ShadowShader!.setImageSampler(0, snapshot.source.image);
      v2ShadowShader!.setImageSampler(1, snapshot.destination.image);
    }
    if (useV2Render && v2RenderShader != null) {
      MorphCoordinator.setUniformsV2Packed(
        shader: v2RenderShader!,
        metadata: metadata,
      );
      v2RenderShader!.setImageSampler(0, snapshot.source.image);
      v2RenderShader!.setImageSampler(1, snapshot.destination.image);
      canvas.drawRect(Offset.zero & size, Paint()..shader = v2RenderShader);
      return;
    }

    // Deprecated emergency fallback path. Remove after V2 stabilization window.
    final fallbackShader = v1Shader ?? shader;
    MorphCoordinator.setUniforms(
      shader: fallbackShader,
      viewport: size,
      sourceRect: snapshot.source,
      targetRect: snapshot.destination,
      time: time,
      progress: shapedProgress,
    );
    canvas.drawRect(Offset.zero & size, Paint()..shader = fallbackShader);
  }

  @override
  bool shouldRepaint(covariant _InternalMorphPainter oldDelegate) => true;
}
