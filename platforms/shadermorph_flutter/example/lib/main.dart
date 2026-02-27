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
      home: ShaderMorphV2DemoPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ShaderMorphV2DemoPage extends StatefulWidget {
  const ShaderMorphV2DemoPage({super.key});

  @override
  State<ShaderMorphV2DemoPage> createState() => _ShaderMorphV2DemoPageState();
}

class _ShaderMorphV2DemoPageState extends State<ShaderMorphV2DemoPage>
    with SingleTickerProviderStateMixin {
  static const String _screenAId = 'screen_a';
  static const String _screenBId = 'screen_b';

  late final ShaderMorphController _controller;
  late final Future<MorphEngine> _engineFuture;
  final MetadataCoordinator _metadataCoordinator = MetadataCoordinator();

  MorphMetadata _metadata = MorphMetadata.empty();
  ui.Image? _fromTexture;
  ui.Image? _toTexture;
  bool _showScreenB = false;
  bool _isMorphActive = false;
  int _morphStyle = 0;
  int _debugMode = 0;

  @override
  void initState() {
    super.initState();
    _controller = ShaderMorphController(vsync: this);
    _engineFuture = MorphEngine.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _fromTexture?.dispose();
    _toTexture?.dispose();
    super.dispose();
  }

  Future<void> _navigate({
    required bool toScreenB,
    required Size logicalSize,
  }) async {
    if (_isMorphActive || _showScreenB == toScreenB) {
      return;
    }

    final viewportSize = ui.Size(logicalSize.width, logicalSize.height);
    final sourceId = toScreenB ? _screenAId : _screenBId;
    final targetId = toScreenB ? _screenBId : _screenAId;

    final metadata = _metadataCoordinator.build(
      sourceScreenId: sourceId,
      targetScreenId: targetId,
      viewportSize: viewportSize,
    );

    final fromTexture = await _drawScreenTexture(
      viewportSize: viewportSize,
      pairCount: metadata.pairCount,
      rects: metadata.sourceRects,
      boxColor: Colors.blue,
      background: const Color(0xFFF1F5F9),
    );
    final toTexture = await _drawScreenTexture(
      viewportSize: viewportSize,
      pairCount: metadata.pairCount,
      rects: metadata.targetRects,
      boxColor: Colors.orange,
      background: const Color(0xFFFFF7ED),
    );

    _fromTexture?.dispose();
    _toTexture?.dispose();

    setState(() {
      _metadata = metadata;
      _fromTexture = fromTexture;
      _toTexture = toTexture;
      _isMorphActive = true;
    });

    await _controller.forward(from: 0.0);
    if (!mounted) {
      return;
    }

    setState(() {
      _showScreenB = toScreenB;
      _isMorphActive = false;
    });
  }

  Future<ui.Image> _drawScreenTexture({
    required ui.Size viewportSize,
    required int pairCount,
    required List<MorphRect> rects,
    required Color boxColor,
    required Color background,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, viewportSize.width, viewportSize.height),
      Paint()..color = background,
    );

    for (int i = 0; i < pairCount && i < rects.length; i++) {
      final rect = rects[i];
      final physicalRect = Rect.fromLTWH(
        rect.x * viewportSize.width,
        rect.y * viewportSize.height,
        rect.width * viewportSize.width,
        rect.height * viewportSize.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(physicalRect, const Radius.circular(16)),
        Paint()..color = boxColor,
      );
    }

    final picture = recorder.endRecording();
    return picture.toImage(
      viewportSize.width.ceil(),
      viewportSize.height.ceil(),
    );
  }

  Future<void> _ensureTextures(Size logicalSize) async {
    if (_fromTexture != null && _toTexture != null) {
      return;
    }

    final viewportSize = ui.Size(logicalSize.width, logicalSize.height);
    final sourceId = _showScreenB ? _screenBId : _screenAId;
    final targetId = _showScreenB ? _screenAId : _screenBId;
    final sourceBoxColor = _showScreenB ? Colors.orange : Colors.blue;
    final targetBoxColor = _showScreenB ? Colors.blue : Colors.orange;
    final sourceBackground =
        _showScreenB ? const Color(0xFFFFF7ED) : const Color(0xFFF1F5F9);
    final targetBackground =
        _showScreenB ? const Color(0xFFF1F5F9) : const Color(0xFFFFF7ED);

    final metadata = _metadataCoordinator.build(
      sourceScreenId: sourceId,
      targetScreenId: targetId,
      viewportSize: viewportSize,
    );

    final fromTexture = await _drawScreenTexture(
      viewportSize: viewportSize,
      pairCount: metadata.pairCount,
      rects: metadata.sourceRects,
      boxColor: sourceBoxColor,
      background: sourceBackground,
    );
    final toTexture = await _drawScreenTexture(
      viewportSize: viewportSize,
      pairCount: metadata.pairCount,
      rects: metadata.targetRects,
      boxColor: targetBoxColor,
      background: targetBackground,
    );

    if (!mounted) {
      fromTexture.dispose();
      toTexture.dispose();
      return;
    }

    _fromTexture?.dispose();
    _toTexture?.dispose();
    setState(() {
      _metadata = metadata;
      _fromTexture = fromTexture;
      _toTexture = toTexture;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final logicalSize = Size(constraints.maxWidth, constraints.maxHeight);

        return Scaffold(
          appBar: AppBar(
            title: const Text('ShaderMorph V2 Demo'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Linear')),
                    ButtonSegment(value: 1, label: Text('Frosted')),
                  ],
                  selected: <int>{_morphStyle},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _morphStyle = selection.first;
                    });
                  },
                ),
              ),
              PopupMenuButton<int>(
                initialValue: _debugMode,
                onSelected: (value) async {
                  setState(() {
                    _debugMode = value;
                  });
                  if (value != 0 &&
                      (_fromTexture == null || _toTexture == null)) {
                    await _ensureTextures(logicalSize);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<int>(value: 0, child: Text('Normal')),
                  PopupMenuItem<int>(value: 1, child: Text('UV')),
                  PopupMenuItem<int>(value: 2, child: Text('RectMask')),
                  PopupMenuItem<int>(value: 3, child: Text('Overlay')),
                  PopupMenuItem<int>(
                    value: 9,
                    child: Text('ForceGradient'),
                  ),
                ],
                icon: const Icon(Icons.bug_report_outlined),
              ),
            ],
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              ShaderMorphScope(
                screenId: _screenAId,
                child: Offstage(
                  offstage: _showScreenB,
                  child: const _ScreenA(),
                ),
              ),
              ShaderMorphScope(
                screenId: _screenBId,
                child: Offstage(
                  offstage: !_showScreenB,
                  child: const _ScreenB(),
                ),
              ),
              if ((_isMorphActive || _debugMode != 0) &&
                  _fromTexture != null &&
                  _toTexture != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: FutureBuilder<MorphEngine>(
                      future: _engineFuture,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const SizedBox.shrink();
                        }
                        return AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) {
                            return CustomPaint(
                              painter: _MorphPainter(
                                engine: snapshot.data!,
                                metadata: _metadata,
                                progress: _controller.progress,
                                morphStyle: _morphStyle,
                                debugMode: _debugMode,
                                fromTexture: _fromTexture!,
                                toTexture: _toTexture!,
                              ),
                              size: Size.infinite,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: () => _navigate(
                      toScreenB: !_showScreenB,
                      logicalSize: logicalSize,
                    ),
                    child: Text(
                      _showScreenB
                          ? 'Navigate to Screen A'
                          : 'Navigate to Screen B',
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScreenA extends StatelessWidget {
  const _ScreenA();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: Stack(
        children: const [
          Positioned(
            left: 32,
            top: 96,
            child: ShaderMorphTag(
              id: 'box_1',
              child: SizedBox(
                width: 90,
                height: 90,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreenB extends StatelessWidget {
  const _ScreenB();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF7ED),
      child: Stack(
        children: const [
          Positioned(
            right: 28,
            bottom: 132,
            child: ShaderMorphTag(
              id: 'box_1',
              child: SizedBox(
                width: 230,
                height: 190,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MorphPainter extends CustomPainter {
  _MorphPainter({
    required this.engine,
    required this.metadata,
    required this.progress,
    required this.morphStyle,
    required this.debugMode,
    required this.fromTexture,
    required this.toTexture,
  });

  final MorphEngine engine;
  final MorphMetadata metadata;
  final double progress;
  final int morphStyle;
  final int debugMode;
  final ui.Image fromTexture;
  final ui.Image toTexture;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = engine.createShader(
      resolutionPx: ui.Size(size.width, size.height),
      progress: progress,
      morphStyle: morphStyle,
      debugMode: debugMode.toDouble(),
      metadata: metadata,
      texFrom: fromTexture,
      texTo: toTexture,
    );
    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _MorphPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.morphStyle != morphStyle ||
        oldDelegate.debugMode != debugMode ||
        oldDelegate.fromTexture != fromTexture ||
        oldDelegate.toTexture != toTexture ||
        oldDelegate.metadata.signature != metadata.signature;
  }
}
