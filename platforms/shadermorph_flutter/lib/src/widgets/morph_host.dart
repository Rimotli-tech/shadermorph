import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../models.dart';
import '../tracker.dart';
import '../coordinator.dart';

class ShaderMorph extends StatefulWidget {
  final Widget source;
  final Widget destination;
  final Duration duration;

  const ShaderMorph({
    super.key,
    required this.source,
    required this.destination,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  State<ShaderMorph> createState() => _ShaderMorphState();
}

class _ShaderMorphState extends State<ShaderMorph>
    with SingleTickerProviderStateMixin {
  final GlobalKey _sourcePaintKey = GlobalKey();
  final GlobalKey _destinationPaintKey = GlobalKey();
  late AnimationController _controller;

  MorphPairSnapshot? _snapshot;
  ui.FragmentProgram? _program;
  bool _isAnimating = false;
  bool _sourceVisible = true;
  bool _destinationVisible = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _cleanupMorph();
        }
      });
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final prog = await ui.FragmentProgram.fromAsset(
        'packages/shadermorph_flutter/shaders/shader_engine.frag',
      );
      if (mounted) setState(() => _program = prog);
    } catch (e) {
      debugPrint('ShaderMorph: Failed to load shader.');
    }
  }

  Future<void> _runMorph() async {
    if (_program == null || _isAnimating) return;

    final data = await MorphTracker.capturePair(
      sourceKey: _sourcePaintKey,
      destinationKey: _destinationPaintKey,
    );

    if (!mounted) return;

    setState(() {
      _snapshot = data;
      _isAnimating = true;
      _sourceVisible = false;
      _destinationVisible = false;
    });

    _showOverlay();
    _controller.forward(from: 0.0);
  }

  void _showOverlay() {
    if (_snapshot == null || _program == null) return;

    final overlayState = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _InternalMorphPainter(
                  shader: _program!.fragmentShader(),
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

  void _cleanupMorph() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() {
        _isAnimating = false;
        _snapshot = null;
        _sourceVisible = false;
        _destinationVisible = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _runMorph,
      child: Column(
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
      ),
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _controller.dispose();
    super.dispose();
  }
}

class _InternalMorphPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final MorphPairSnapshot snapshot;
  final double time;
  final double progress;

  _InternalMorphPainter({
    required this.shader,
    required this.snapshot,
    required this.time,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    MorphCoordinator.setUniforms(
      shader: shader,
      viewport: size,
      sourceRect: snapshot.source,
      targetRect: snapshot.destination,
      time: time,
      progress: progress,
    );
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _InternalMorphPainter oldDelegate) => true;
}
