import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// Assuming your package name in pubspec is shadermorph_flutter
import 'package:shadermorph_flutter/src/tracker.dart';
import 'package:shadermorph_flutter/src/coordinator.dart';

void main() => runApp(const MaterialApp(home: ShaderMorph()));

class ShaderMorph extends StatefulWidget {
  const ShaderMorph({super.key});
  @override
  State<ShaderMorph> createState() => _ShaderMorphState();
}

class _ShaderMorphState extends State<ShaderMorph>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final GlobalKey _paintKey = GlobalKey();
  ui.Image? _snapshot;
  Rect? _sourceRect; // NEW: Storing the geometry
  ui.FragmentProgram? _program;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); // This makes it loop forever 0.0 -> 1.0
    _loadResources();
  }

  Future<void> _loadResources() async {
    final prog = await ui.FragmentProgram.fromAsset(
      'packages/shadermorph_flutter/core_shaders/engine/shader_engine.frag',
    );

    // Automation: Wait for the frame to draw, then capture
    WidgetsBinding.instance.addPostFrameCallback((_) => _takeSnapshot());

    setState(() => _program = prog);
  }

  Future<void> _takeSnapshot() async {
    // BLOCK 1: Using the Tracker (The Camera)
    final data = await MorphTracker.capture(_paintKey);

    setState(() {
      _snapshot = data['image'];
      _sourceRect = data['rect'];
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_program == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          // THE REAL WIDGET: Hidden in plain sight
          Center(
            child: RepaintBoundary(
              key: _paintKey,
              child: Container(
                width: 200,
                height: 200,
                color: Colors.blue,
                child: const Center(
                  child: Text(
                    "HELLO GPU",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (_snapshot != null && _sourceRect != null)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: MorphPainter(
                      program: _program!,
                      image: _snapshot!,
                      sourceRect: _sourceRect!,
                      time:
                          _controller.value *
                          6.28, // Pass 0 to 2*PI for a full wave cycle
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class MorphPainter extends CustomPainter {
  MorphPainter({
    required this.program,
    required this.image,
    required this.sourceRect,
    required this.time,
  });

  final ui.FragmentProgram program;
  final ui.Image image;
  final Rect sourceRect;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();

    MorphCoordinator.setUniforms(
      shader: shader,
      viewport: size,
      sourceRect: sourceRect,
      texture: image,
      time: time,
    );

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
