import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shadermorph_flutter/shadermorph_flutter.dart';

void main() {
  runApp(const MorphPaperRipDemoApp());
}

class MorphPaperRipDemoApp extends StatelessWidget {
  const MorphPaperRipDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MorphPaperRipPage(),
    );
  }
}

class MorphPaperRipPage extends StatefulWidget {
  const MorphPaperRipPage({super.key});

  @override
  State<MorphPaperRipPage> createState() => _MorphPaperRipPageState();
}

class _MorphPaperRipPageState extends State<MorphPaperRipPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Future<_DemoResources> _resourcesFuture;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _resourcesFuture = _loadResources();
  }

  Future<_DemoResources> _loadResources() async {
    final loaded = await Future.wait<Object>([
      MorphPaperRipTransition.load(),
      MorphFrostedGlassTransition.load(),
    ]);

    final texture0 = await _createSolidImage(const Color(0xFF1C2538));
    final texture1 = await _createSolidImage(const Color(0xFFE1863A));

    final transitions = <_GalleryTransition>[
      _GalleryTransition(
        name: 'Paper Rip',
        transition: loaded[0] as MorphPaperRipTransition,
      ),
      _GalleryTransition(
        name: 'Frosted Glass',
        transition: loaded[1] as MorphFrostedGlassTransition,
      ),
    ];

    return _DemoResources(
      transitions: transitions,
      texture0: texture0,
      texture1: texture1,
    );
  }

  Future<ui.Image> _createSolidImage(Color color) async {
    const int width = 1024;
    const int height = 1024;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = color;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      paint,
    );
    final picture = recorder.endRecording();
    return picture.toImage(width, height);
  }

  void _showPrevious(int count) {
    setState(() {
      _currentIndex = (_currentIndex - 1 + count) % count;
    });
  }

  void _showNext(int count) {
    setState(() {
      _currentIndex = (_currentIndex + 1) % count;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shader Gallery')),
      body: FutureBuilder<_DemoResources>(
        future: _resourcesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final resources = snapshot.data!;
          final active = resources.transitions[_currentIndex];
          return Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _ShaderGalleryPainter(
                        transition: active.transition,
                        uTexture0: resources.texture0,
                        uTexture1: resources.texture1,
                        uProgress: _controller.value,
                        uTime:
                            (_controller.lastElapsedDuration?.inMilliseconds ??
                                    0) /
                                1000.0,
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      active.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'prev_transition',
                      onPressed: () => _showPrevious(resources.transitions.length),
                      child: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 16),
                    FloatingActionButton.small(
                      heroTag: 'next_transition',
                      onPressed: () => _showNext(resources.transitions.length),
                      child: const Icon(Icons.arrow_forward),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ShaderGalleryPainter extends CustomPainter {
  _ShaderGalleryPainter({
    required this.transition,
    required this.uTexture0,
    required this.uTexture1,
    required this.uProgress,
    required this.uTime,
  });

  final ShaderTransition transition;
  final ui.Image uTexture0;
  final ui.Image uTexture1;
  final double uProgress;
  final double uTime;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = transition.createShader(
      uProgress: uProgress,
      uResolution: size,
      uTime: uTime,
      uTexture0: uTexture0,
      uTexture1: uTexture1,
    );

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _ShaderGalleryPainter oldDelegate) {
    return oldDelegate.uProgress != uProgress ||
        oldDelegate.uTime != uTime ||
        oldDelegate.uTexture0 != uTexture0 ||
        oldDelegate.uTexture1 != uTexture1 ||
        oldDelegate.transition != transition;
  }
}

class _GalleryTransition {
  const _GalleryTransition({
    required this.name,
    required this.transition,
  });

  final String name;
  final ShaderTransition transition;
}

class _DemoResources {
  const _DemoResources({
    required this.transitions,
    required this.texture0,
    required this.texture1,
  });

  final List<_GalleryTransition> transitions;
  final ui.Image texture0;
  final ui.Image texture1;
}