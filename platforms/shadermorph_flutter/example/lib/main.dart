import 'dart:ui' as ui;
import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(home: ShaderMorph()));
}

class ShaderMorph extends StatefulWidget {
  const ShaderMorph({super.key});

  @override
  State<ShaderMorph> createState() => _ShaderMorphState();
}

class _ShaderMorphState extends State<ShaderMorph> {
  // Load the program from assets
  final Future<ui.FragmentProgram> _program = ui.FragmentProgram.fromAsset(
    'packages/shadermorph_flutter/core_shaders/engine/morph_engine0.frag',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<ui.FragmentProgram>(
        future: _program,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return CustomPaint(
            // Use the full screen for the gradient
            size: Size.infinite,
            painter: GradientPainter(snapshot.data!),
          );
        },
      ),
    );
  }
}

class GradientPainter extends CustomPainter {
  GradientPainter(this.program);
  final ui.FragmentProgram program;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();

    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);

    final paint = Paint()..shader = shader;

    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
