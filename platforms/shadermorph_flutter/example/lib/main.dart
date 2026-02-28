import 'dart:ui' as ui;

import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(home: MorphShaderDemo()));
}

class MorphShaderDemo extends StatefulWidget {
  const MorphShaderDemo({super.key});

  @override
  State<MorphShaderDemo> createState() => _MorphShaderDemoState();
}

class _MorphShaderDemoState extends State<MorphShaderDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Future<ui.FragmentProgram> _program;
  bool _toCircle = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _program = ui.FragmentProgram.fromAsset('shaders/morph_shape.frag');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _toCircle = !_toCircle;
    });
    if (_toCircle) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder<ui.FragmentProgram>(
              future: _program,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(width: 220, height: 220);
                }
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return CustomPaint(
                      size: const Size(220, 220),
                      painter: _MorphPainter(
                        program: snapshot.data!,
                        progress: _controller.value,
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _toggle,
              child: Text(_toCircle ? 'Morph to Rectangle' : 'Morph to Circle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MorphPainter extends CustomPainter {
  _MorphPainter({required this.program, required this.progress});

  final ui.FragmentProgram program;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();

    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, progress);
    shader.setFloat(3, 1.0);
    shader.setFloat(4, 0.0);

    shader.setFloat(5, 0.25);
    shader.setFloat(6, 0.25);
    shader.setFloat(7, 0.5);
    shader.setFloat(8, 0.5);

    for (int i = 1; i < 8; i++) {
      final base = 5 + (i * 4);
      shader.setFloat(base + 0, 0.0);
      shader.setFloat(base + 1, 0.0);
      shader.setFloat(base + 2, 0.0);
      shader.setFloat(base + 3, 0.0);
    }

    final int targetStart = 5 + (8 * 4);
    for (int i = 0; i < 8; i++) {
      final base = targetStart + (i * 4);
      shader.setFloat(base + 0, i == 0 ? 0.25 : 0.0);
      shader.setFloat(base + 1, i == 0 ? 0.25 : 0.0);
      shader.setFloat(base + 2, i == 0 ? 0.5 : 0.0);
      shader.setFloat(base + 3, i == 0 ? 0.5 : 0.0);
    }

    final int debugIndex = targetStart + (8 * 4);
    shader.setFloat(debugIndex, 0.0);
    shader.setFloat(debugIndex + 1, 0.0);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _MorphPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.program != program;
  }
}
