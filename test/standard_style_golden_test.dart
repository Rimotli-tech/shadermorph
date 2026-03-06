import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const scenarios = <_Scenario>[
    _Scenario(
      id: 'circle_to_rectangle_small_to_large',
      originRect: Rect.fromLTWH(32, 32, 56, 56),
      destinationRect: Rect.fromLTWH(92, 56, 170, 110),
      originIsCircle: true,
      destinationIsCircle: false,
    ),
    _Scenario(
      id: 'circle_to_rectangle_large_to_small',
      originRect: Rect.fromLTWH(24, 36, 160, 160),
      destinationRect: Rect.fromLTWH(180, 90, 64, 48),
      originIsCircle: true,
      destinationIsCircle: false,
    ),
    _Scenario(
      id: 'rectangle_to_circle',
      originRect: Rect.fromLTWH(28, 52, 164, 92),
      destinationRect: Rect.fromLTWH(196, 66, 84, 84),
      originIsCircle: false,
      destinationIsCircle: true,
    ),
    _Scenario(
      id: 'portrait_to_landscape_rect',
      originRect: Rect.fromLTWH(24, 36, 72, 164),
      destinationRect: Rect.fromLTWH(120, 94, 190, 70),
      originIsCircle: false,
      destinationIsCircle: false,
    ),
  ];

  const progressPoints = <double>[0.0, 0.25, 0.5, 0.75, 1.0];

  for (final scenario in scenarios) {
    for (final progress in progressPoints) {
      testWidgets('${scenario.id} @ ${progress.toStringAsFixed(2)}', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(360, 240));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: const Color(0xFF0F1012),
              body: Center(
                child: RepaintBoundary(
                  key: const ValueKey<String>('preview-boundary'),
                  child: CustomPaint(
                    size: const Size(360, 240),
                    painter: _MorphPreviewPainter(
                      originRect: scenario.originRect,
                      destinationRect: scenario.destinationRect,
                      originIsCircle: scenario.originIsCircle,
                      destinationIsCircle: scenario.destinationIsCircle,
                      progress: progress,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final p = progress.toStringAsFixed(2).replaceAll('.', '_');
        await expectLater(
          find.byKey(const ValueKey<String>('preview-boundary')),
          matchesGoldenFile('goldens/standard_style/${scenario.id}_$p.png'),
        );
      });
    }
  }
}

class _Scenario {
  final String id;
  final Rect originRect;
  final Rect destinationRect;
  final bool originIsCircle;
  final bool destinationIsCircle;

  const _Scenario({
    required this.id,
    required this.originRect,
    required this.destinationRect,
    required this.originIsCircle,
    required this.destinationIsCircle,
  });
}

class _MorphPreviewPainter extends CustomPainter {
  final Rect originRect;
  final Rect destinationRect;
  final bool originIsCircle;
  final bool destinationIsCircle;
  final double progress;

  const _MorphPreviewPainter({
    required this.originRect,
    required this.destinationRect,
    required this.originIsCircle,
    required this.destinationIsCircle,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.clamp(0.0, 1.0);
    final movedRect = Rect.lerp(originRect, destinationRect, t)!;

    // Paper-like backdrop for stable visual comparisons.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF15171A), Color(0xFF0E0F11)],
        ).createShader(Offset.zero & size),
    );

    _drawShapeLayer(
      canvas: canvas,
      rect: movedRect,
      isCircle: originIsCircle,
      color: const Color(0xFF61B5FF),
      alpha: (1.0 - t).toDouble(),
      accent: const Color(0xFFB6E1FF),
    );
    _drawShapeLayer(
      canvas: canvas,
      rect: movedRect,
      isCircle: destinationIsCircle,
      color: const Color(0xFFFFA273),
      alpha: t.toDouble(),
      accent: const Color(0xFFFFD3BE),
    );

    // Frame guide.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x22FFFFFF),
    );
  }

  void _drawShapeLayer({
    required Canvas canvas,
    required Rect rect,
    required bool isCircle,
    required Color color,
    required Color accent,
    required double alpha,
  }) {
    if (alpha <= 0.0) return;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          accent.withValues(alpha: alpha),
          color.withValues(alpha: alpha),
        ],
      ).createShader(rect);
    if (isCircle) {
      canvas.drawOval(rect, paint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(18)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MorphPreviewPainter oldDelegate) {
    return oldDelegate.originRect != originRect ||
        oldDelegate.destinationRect != destinationRect ||
        oldDelegate.originIsCircle != originIsCircle ||
        oldDelegate.destinationIsCircle != destinationIsCircle ||
        oldDelegate.progress != progress;
  }
}
