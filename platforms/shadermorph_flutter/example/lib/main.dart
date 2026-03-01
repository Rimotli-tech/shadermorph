import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

void main() => runApp(const MaterialApp(home: ShaderMorph()));

class ShaderMorph extends StatefulWidget {
  const ShaderMorph({super.key});
  @override
  State<ShaderMorph> createState() => _ShaderMorphState();
}

class _ShaderMorphState extends State<ShaderMorph> {
  final GlobalKey _paintKey = GlobalKey();
  ui.Image? _snapshot;
  ui.FragmentProgram? _program;

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    // 1. Load the shader
    final prog = await ui.FragmentProgram.fromAsset(
      'packages/shadermorph_flutter/core_shaders/engine/shader_engine.frag',
    );

    // 2. Schedule the snapshot for AFTER the first frame is drawn
    WidgetsBinding.instance.addPostFrameCallback((_) => _takeSnapshot());

    setState(() => _program = prog);
  }

  Future<void> _takeSnapshot() async {
    final boundary =
        _paintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage();
    setState(() => _snapshot = image);
  }

  @override
  Widget build(BuildContext context) {
    if (_program == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          // THE CAMERA: Capturing this container
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

          // THE ARTIST: The Shader sitting on top
          if (_snapshot != null)
            Positioned.fill(
              child: CustomPaint(painter: MorphPainter(_program!, _snapshot!)),
            ),
        ],
      ),
    );
  }
}

class MorphPainter extends CustomPainter {
  MorphPainter(this.program, this.image);
  final ui.FragmentProgram program;
  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setImageSampler(0, image);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
