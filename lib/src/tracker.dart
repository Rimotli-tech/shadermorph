import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'models.dart';
import 'models_v2.dart';

class MorphCaptureOptions {
  final MorphShadowCapturePolicy shadowPolicy;

  const MorphCaptureOptions({
    this.shadowPolicy = MorphShadowCapturePolicy.exclude,
  });
}

class MorphCaptureLayerRegistry {
  MorphCaptureLayerRegistry._();

  static final MorphCaptureLayerRegistry instance =
      MorphCaptureLayerRegistry._();

  final Map<GlobalKey, GlobalKey> _captureKeyByHost = <GlobalKey, GlobalKey>{};

  void register({required GlobalKey hostKey, required GlobalKey captureKey}) {
    _captureKeyByHost[hostKey] = captureKey;
  }

  void unregister(GlobalKey hostKey) {
    _captureKeyByHost.remove(hostKey);
  }

  GlobalKey? captureKeyFor(GlobalKey hostKey) => _captureKeyByHost[hostKey];
}

class ShaderMorphCaptureLayer extends StatefulWidget {
  final GlobalKey boundaryKey;
  final MorphShadowCapturePolicy shadowCapturePolicy;
  final Widget? captureChild;
  final Widget child;

  const ShaderMorphCaptureLayer({
    super.key,
    required this.boundaryKey,
    required this.shadowCapturePolicy,
    this.captureChild,
    required this.child,
  });

  @override
  State<ShaderMorphCaptureLayer> createState() =>
      _ShaderMorphCaptureLayerState();
}

class _ShaderMorphCaptureLayerState extends State<ShaderMorphCaptureLayer> {
  final GlobalKey _captureKey = GlobalKey();
  static const List<double> _transparentColorMatrix = <double>[
    1.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    1.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    1.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
  ];

  @override
  void initState() {
    super.initState();
    _syncRegistry();
  }

  @override
  void didUpdateWidget(covariant ShaderMorphCaptureLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.boundaryKey, widget.boundaryKey)) {
      MorphCaptureLayerRegistry.instance.unregister(oldWidget.boundaryKey);
    }
    _syncRegistry();
  }

  @override
  void dispose() {
    MorphCaptureLayerRegistry.instance.unregister(widget.boundaryKey);
    super.dispose();
  }

  void _syncRegistry() {
    final hasDedicatedCapture = widget.captureChild != null;
    if (widget.shadowCapturePolicy == MorphShadowCapturePolicy.exclude &&
        hasDedicatedCapture) {
      MorphCaptureLayerRegistry.instance.register(
        hostKey: widget.boundaryKey,
        captureKey: _captureKey,
      );
      return;
    }
    MorphCaptureLayerRegistry.instance.unregister(widget.boundaryKey);
  }

  @override
  Widget build(BuildContext context) {
    final captureChild = widget.captureChild;
    if (widget.shadowCapturePolicy == MorphShadowCapturePolicy.exclude &&
        captureChild != null) {
      return RepaintBoundary(
        key: widget.boundaryKey,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            widget.child,
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.matrix(
                      _transparentColorMatrix,
                    ),
                    child: RepaintBoundary(
                      key: _captureKey,
                      child: captureChild,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return RepaintBoundary(key: widget.boundaryKey, child: widget.child);
  }
}

class MorphTracker {
  static Rect logicalRectToPhysicalRect({
    required Rect logicalRect,
    required double devicePixelRatio,
  }) {
    return Rect.fromLTWH(
      logicalRect.left * devicePixelRatio,
      logicalRect.top * devicePixelRatio,
      logicalRect.width * devicePixelRatio,
      logicalRect.height * devicePixelRatio,
    );
  }

  static Size logicalSizeToPhysicalSize({
    required Size logicalSize,
    required double devicePixelRatio,
  }) {
    return Size(
      logicalSize.width * devicePixelRatio,
      logicalSize.height * devicePixelRatio,
    );
  }

  static MorphRectNormV2 normalizePhysicalRectToV2({
    required Rect physicalRect,
    required Size resolutionPx,
    bool clampToUnit = false,
  }) {
    if (!resolutionPx.width.isFinite ||
        !resolutionPx.height.isFinite ||
        resolutionPx.width <= 0.0 ||
        resolutionPx.height <= 0.0) {
      return MorphRectNormV2.zero;
    }

    final normalized = MorphRectNormV2(
      x: physicalRect.left / resolutionPx.width,
      y: physicalRect.top / resolutionPx.height,
      w: physicalRect.width / resolutionPx.width,
      h: physicalRect.height / resolutionPx.height,
    );

    if (!clampToUnit) {
      return normalized;
    }
    return normalized.clampedToUnit();
  }

  static MorphRectNormV2 normalizeLogicalRectToV2({
    required Rect logicalRect,
    required Size logicalResolution,
    required double devicePixelRatio,
    bool clampToUnit = false,
  }) {
    if (!devicePixelRatio.isFinite || devicePixelRatio <= 0.0) {
      return MorphRectNormV2.zero;
    }

    final physicalRect = logicalRectToPhysicalRect(
      logicalRect: logicalRect,
      devicePixelRatio: devicePixelRatio,
    );
    final physicalResolution = logicalSizeToPhysicalSize(
      logicalSize: logicalResolution,
      devicePixelRatio: devicePixelRatio,
    );

    return normalizePhysicalRectToV2(
      physicalRect: physicalRect,
      resolutionPx: physicalResolution,
      clampToUnit: clampToUnit,
    );
  }

  static Future<MorphSnapshot> capture(
    GlobalKey key, {
    MorphCaptureOptions options = const MorphCaptureOptions(),
  }) async {
    return _captureSingle(key, options: options);
  }

  static Future<MorphPairSnapshot> capturePair({
    required GlobalKey originKey,
    required GlobalKey destinationKey,
    MorphCaptureOptions captureOptions = const MorphCaptureOptions(),
  }) async {
    final origin = await _captureSingle(originKey, options: captureOptions);
    final destination = await _captureSingle(
      destinationKey,
      options: captureOptions,
    );
    return MorphPairSnapshot(origin: origin, destination: destination);
  }

  static Future<MorphSnapshot> _captureSingle(
    GlobalKey key, {
    required MorphCaptureOptions options,
  }) async {
    final captureKey = _resolvedCaptureKey(key, options);
    final context = captureKey.currentContext;
    if (context == null) throw Exception("MorphTracker: Context not found.");

    final renderBox =
        captureKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) throw Exception("Could not find RenderBox");

    // Get Global Position
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final rect = Rect.fromLTWH(
      position.dx,
      position.dy,
      size.width,
      size.height,
    );

    // Get Pixels
    final boundary = renderBox as RenderRepaintBoundary;
    final pixelRatio = View.of(context).devicePixelRatio;
    final image = await boundary.toImage(pixelRatio: pixelRatio);

    return MorphSnapshot(image: image, rect: rect, pixelRatio: pixelRatio);
  }

  static GlobalKey _resolvedCaptureKey(
    GlobalKey hostKey,
    MorphCaptureOptions options,
  ) {
    if (options.shadowPolicy == MorphShadowCapturePolicy.exclude) {
      return MorphCaptureLayerRegistry.instance.captureKeyFor(hostKey) ??
          hostKey;
    }
    return hostKey;
  }
}
