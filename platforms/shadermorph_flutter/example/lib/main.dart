import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// Assuming your package name in pubspec is shadermorph_flutter
import 'package:shadermorph_flutter/src/tracker.dart';
import 'package:shadermorph_flutter/src/coordinator.dart';
import 'package:shadermorph_flutter/src/models.dart';

void main() => runApp(const MaterialApp(home: ShaderMorph()));

class ShaderMorph extends StatefulWidget {
  const ShaderMorph({super.key});
  @override
  State<ShaderMorph> createState() => _ShaderMorphState();
}

class _ShaderMorphState extends State<ShaderMorph>
    with SingleTickerProviderStateMixin {
  bool _isActive = false;
  late AnimationController _controller;
  final GlobalKey _paintKey = GlobalKey();

  ui.FragmentProgram? _program;

  MorphSnapshot? _snapshot;

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
      'packages/shadermorph_flutter/shaders/shader_engine.frag',
    );

    setState(() => _program = prog);
  }

  Future<void> _takeSnapshot() async {
    final data = await MorphTracker.capture(_paintKey);

    setState(() {
      _snapshot = data; // Store the whole object
      _isActive = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_program == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: Stack(
        children: [
          Opacity(
            opacity: _isActive ? 0.0 : 1.0,
            child: Center(
              child: GestureDetector(
                onTap: _takeSnapshot,
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
            ),
          ),

          // THE SHADER OVERLAY
          if (_isActive && _snapshot != null)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: MorphPainter(
                      program: _program!,
                      snapshot: _snapshot!, // FIX: Pass the object, not pieces
                      time: _controller.value * 6.28,
                      progress:
                          _controller.value, // FIX: Pass the required progress
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
    required this.snapshot, // Updated to take the object
    required this.time,
    required this.progress, // Added required progress
  });

  final ui.FragmentProgram program;
  final MorphSnapshot snapshot;
  final double time;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();

    // FIX: Match the new Coordinator signature exactly
    MorphCoordinator.setUniforms(
      shader: shader,
      viewport: size,
      sourceRect: snapshot, // The Coordinator uses this snapshot for image/rect
      time: time,
      progress: progress, // Passing the float to Slot 7
    );

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant MorphPainter oldDelegate) => true;
}
