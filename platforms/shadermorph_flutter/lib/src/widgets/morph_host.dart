import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../models.dart';
import '../tracker.dart';
import '../coordinator.dart';
import '../controller.dart';
import '../cross_route.dart';
import '../navigation.dart';
import '../runtime_config.dart';
import '../transition_config.dart';

enum ShaderMorphTriggerMode {
  manual,
  tapToggle,
  tapForward,
  tapReverse,
  onBuildForward,
}

enum ShaderMorphEventType {
  startedForward,
  completedForward,
  startedReverse,
  completedReverse,
  failed,
  popped,
}

class ShaderMorphEvent {
  final ShaderMorphEventType type;

  const ShaderMorphEvent(this.type);
}

class ShaderMorphHandle {
  final Future<bool> Function() _forward;
  final Future<bool> Function() _reverse;
  final Future<bool> Function() _toggle;

  const ShaderMorphHandle(this._forward, this._reverse, this._toggle);

  Future<bool> forward() => _forward();
  Future<bool> reverse() => _reverse();
  Future<bool> toggle() => _toggle();

  static ShaderMorphHandle of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_ShaderMorphScope>();
    if (scope == null) {
      throw FlutterError(
        'ShaderMorphHandle.of(context) called with no ShaderMorph ancestor.',
      );
    }
    return scope.handle;
  }
}

class _ShaderMorphScope extends InheritedWidget {
  final ShaderMorphHandle handle;

  const _ShaderMorphScope({required this.handle, required super.child});

  @override
  bool updateShouldNotify(covariant _ShaderMorphScope oldWidget) =>
      oldWidget.handle != handle;
}

class ShaderMorph extends StatefulWidget {
  final Widget source;
  final Widget destination;
  final Widget? sourceCapture;
  final Widget? destinationCapture;
  final Duration duration;
  final ShaderMorphController? controller;
  final MorphTransitionConfig transitionConfig;
  final BackPopMode backPopMode;
  final MorphShadowCapturePolicy shadowCapturePolicy;
  final ShaderMorphTriggerMode triggerMode;
  final ValueChanged<ShaderMorphEvent>? onEvent;
  final Widget Function(BuildContext context, Widget morphChild)? childBuilder;

  static final Map<String, CrossRouteMorphController> _routeControllers =
      <String, CrossRouteMorphController>{};

  static Widget tag({
    required String id,
    required Widget child,
    Widget? captureChild,
    MorphShadowCapturePolicy shadowCapturePolicy =
        MorphShadowCapturePolicy.exclude,
  }) {
    return MorphTag(
      id: id,
      captureChild: captureChild,
      shadowCapturePolicy: shadowCapturePolicy,
      child: child,
    );
  }

  static Future<bool> push({
    required BuildContext context,
    required String tagId,
    required Widget page,
    MorphTransitionConfig transitionConfig = const MorphTransitionConfig(),
    BackPopMode backPopMode = BackPopMode.reverseThenPop,
    MorphShadowCapturePolicy shadowCapturePolicy =
        MorphShadowCapturePolicy.exclude,
    bool suppressTransition = true,
    RouteSettings? settings,
  }) async {
    final controller = CrossRouteMorphController(
      transitionConfig: transitionConfig,
      shadowCapturePolicy: shadowCapturePolicy,
    );
    _routeControllers[tagId]?.dispose();
    _routeControllers[tagId] = controller;
    final wrappedPage = _ShaderMorphCrossRouteScope(
      tagId: tagId,
      controller: controller,
      backPopMode: backPopMode,
      child: page,
    );
    return controller.startToRoute(
      context: context,
      tagId: tagId,
      route: buildMorphRoute(
        page: wrappedPage,
        suppressTransition: suppressTransition,
        settings: settings,
      ),
    );
  }

  static Future<bool> reverseAndPop(
    BuildContext context, {
    required String tagId,
    Object? result,
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    final controller = _routeControllers[tagId];
    if (controller == null) {
      if (context.mounted) {
        Navigator.of(context).maybePop(result);
      }
      return false;
    }
    final ok = await controller.playReverseDuringPop(
      context: context,
      tagId: tagId,
      result: result,
      timeout: timeout,
    );
    if (!ok && context.mounted) {
      Navigator.of(context).maybePop(result);
    }
    _releaseRouteController(tagId, controller);
    return ok;
  }

  static void _releaseRouteController(
    String tagId,
    CrossRouteMorphController controller,
  ) {
    final active = _routeControllers[tagId];
    if (identical(active, controller)) {
      _routeControllers.remove(tagId);
    }
    controller.dispose();
  }

  const ShaderMorph({
    super.key,
    required this.source,
    required this.destination,
    this.sourceCapture,
    this.destinationCapture,
    this.controller,
    this.duration = const Duration(milliseconds: 800),
    this.transitionConfig = const MorphTransitionConfig(),
    this.backPopMode = BackPopMode.reverseThenPop,
    this.shadowCapturePolicy = MorphShadowCapturePolicy.exclude,
    this.triggerMode = ShaderMorphTriggerMode.manual,
    this.onEvent,
    this.childBuilder,
  });

  @override
  State<ShaderMorph> createState() => _ShaderMorphState();
}

class _ShaderMorphState extends State<ShaderMorph>
    with SingleTickerProviderStateMixin
    implements ShaderMorphPlaybackDelegate {
  final GlobalKey _sourcePaintKey = GlobalKey();
  final GlobalKey _destinationPaintKey = GlobalKey();
  late AnimationController _controller;

  MorphPairSnapshot? _snapshot;
  ui.FragmentProgram? _program;
  // Deprecated emergency fallback path. Remove after V2 stabilization window.
  ui.FragmentProgram? _v1Program;
  ui.FragmentShader? _v2ShadowShader;
  ui.FragmentShader? _v2RenderShader;
  MorphDirection _activeDirection = MorphDirection.forward;
  MorphPlaybackState _playbackState = MorphPlaybackState.idleSource;
  bool _sourceVisible = true;
  bool _destinationVisible = false;
  OverlayEntry? _overlayEntry;
  ShaderMorphController? _ownedController;
  bool _didRunBuildForward = false;
  bool _handlingPop = false;
  bool _allowNextPop = false;

  ShaderMorphController get _effectiveController =>
      widget.controller ?? (_ownedController ??= ShaderMorphController());

  void _emit(ShaderMorphEventType type) {
    widget.onEvent?.call(ShaderMorphEvent(type));
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _completeMorph();
        }
      });
    _effectiveController.attach(this);
    _effectiveController.setStateFromHost(_playbackState);
    _loadShader();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.triggerMode == ShaderMorphTriggerMode.onBuildForward &&
          !_didRunBuildForward) {
        _didRunBuildForward = true;
        unawaited(_forward());
      }
    });
  }

  Future<void> _loadShader() async {
    try {
      final v1Prog = await ui.FragmentProgram.fromAsset(
        'packages/shadermorph_flutter/shaders/shader_engine.frag',
      );
      ui.FragmentProgram? v2Prog;
      try {
        v2Prog = await ui.FragmentProgram.fromAsset(
          'packages/shadermorph_flutter/shaders/shader_engine_v2.frag',
        );
      } catch (_) {
        // Keep rendering available via V1 fallback if V2 cannot load.
      }

      final config = MorphRuntimeConfig.current;
      maybeLogRuntimeDeprecations(config);

      ui.FragmentShader? shadowShader;
      if (config.enableV2ShadowBindWhenV1 && v2Prog != null) {
        shadowShader = v2Prog.fragmentShader();
      }
      final renderShader = config.useV2SinglePageRender && v2Prog != null
          ? v2Prog.fragmentShader()
          : null;

      final activeProgram = v2Prog ?? v1Prog;
      if (mounted) setState(() => _program = activeProgram);
      _v1Program = v1Prog;
      _v2ShadowShader = shadowShader;
      _v2RenderShader = renderShader;
    } catch (e) {
      debugPrint('ShaderMorph: Failed to load shader.');
    }
  }

  @override
  void didUpdateWidget(covariant ShaderMorph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      final oldEffective = oldWidget.controller ?? _ownedController;
      oldEffective?.detach(this);
      _effectiveController.attach(this);
      _effectiveController.setStateFromHost(_playbackState);
    }
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  Future<bool> play({required MorphDirection direction}) async {
    if (_program == null) return false;
    if (_isAnimating) return false;
    if (!_canPlay(direction)) return false;

    _activeDirection = direction;
    final data = await MorphTracker.capturePair(
      sourceKey: direction == MorphDirection.forward
          ? _sourcePaintKey
          : _destinationPaintKey,
      destinationKey: direction == MorphDirection.forward
          ? _destinationPaintKey
          : _sourcePaintKey,
      captureOptions: MorphCaptureOptions(
        shadowPolicy: widget.shadowCapturePolicy,
      ),
    );

    if (!mounted) return false;

    setState(() {
      _snapshot = data;
      _playbackState = direction == MorphDirection.forward
          ? MorphPlaybackState.animatingForward
          : MorphPlaybackState.animatingReverse;
      _sourceVisible = false;
      _destinationVisible = false;
    });
    _effectiveController.setStateFromHost(_playbackState);
    _emit(
      direction == MorphDirection.forward
          ? ShaderMorphEventType.startedForward
          : ShaderMorphEventType.startedReverse,
    );

    _showOverlay();
    try {
      await _controller.forward(from: 0.0);
      return true;
    } catch (_) {
      _emit(ShaderMorphEventType.failed);
      return false;
    }
  }

  Future<bool> _forward() => play(direction: MorphDirection.forward);

  Future<bool> _reverse() => play(direction: MorphDirection.reverse);

  Future<bool> _toggle() {
    if (_playbackState == MorphPlaybackState.idleSource) {
      return _forward();
    }
    if (_playbackState == MorphPlaybackState.idleDestination) {
      return _reverse();
    }
    return Future<bool>.value(false);
  }

  void _showOverlay() {
    if (_snapshot == null || _program == null) return;

    final overlayState = Overlay.of(context);
    final config = MorphRuntimeConfig.current;
    final v1Shader = _v1Program?.fragmentShader();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _InternalMorphPainter(
                  shader: _program!.fragmentShader(),
                  v1Shader: v1Shader,
                  v2ShadowShader: _v2ShadowShader,
                  v2RenderShader: _v2RenderShader,
                  useV2Render: config.useV2SinglePageRender,
                  transitionConfig: widget.transitionConfig,
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

  bool get _isAnimating =>
      _playbackState == MorphPlaybackState.animatingForward ||
      _playbackState == MorphPlaybackState.animatingReverse;

  bool _canPlay(MorphDirection direction) {
    if (direction == MorphDirection.forward) {
      return _playbackState == MorphPlaybackState.idleSource;
    }
    return _playbackState == MorphPlaybackState.idleDestination;
  }

  void _completeMorph() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() {
        _snapshot = null;
        if (_activeDirection == MorphDirection.forward) {
          _playbackState = MorphPlaybackState.idleDestination;
          _sourceVisible = false;
          _destinationVisible = true;
        } else {
          _playbackState = MorphPlaybackState.idleSource;
          _sourceVisible = true;
          _destinationVisible = false;
        }
      });
      _effectiveController.setStateFromHost(_playbackState);
      _emit(
        _activeDirection == MorphDirection.forward
            ? ShaderMorphEventType.completedForward
            : ShaderMorphEventType.completedReverse,
      );
    }
  }

  Future<void> _popWithBypass(NavigatorState navigator, Object? result) async {
    if (!mounted || !navigator.mounted) return;
    setState(() {
      _allowNextPop = true;
    });
    try {
      if (navigator.canPop()) {
        navigator.pop(result);
      } else {
        await navigator.maybePop(result);
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _allowNextPop = false;
      });
    }
  }

  Future<void> _handleBackPop(Object? result) async {
    if (_handlingPop) return;
    _handlingPop = true;
    final navigator = Navigator.of(context);
    try {
      if (widget.backPopMode == BackPopMode.immediatePopReset) {
        _effectiveController.resetToSource();
        await _popWithBypass(navigator, result);
        _emit(ShaderMorphEventType.popped);
        return;
      }

      if (_playbackState != MorphPlaybackState.idleDestination) {
        await _popWithBypass(navigator, result);
        _emit(ShaderMorphEventType.popped);
        return;
      }

      final started = await _reverse();
      if (!started) {
        await _popWithBypass(navigator, result);
        _emit(ShaderMorphEventType.popped);
        return;
      }

      final completed = await _effectiveController.waitForState(
        MorphPlaybackState.idleSource,
        timeout: const Duration(milliseconds: 1200),
      );
      if (completed || navigator.mounted) {
        await _popWithBypass(navigator, result);
        _emit(ShaderMorphEventType.popped);
      }
    } finally {
      _handlingPop = false;
    }
  }

  void _handleTapTrigger() {
    switch (widget.triggerMode) {
      case ShaderMorphTriggerMode.manual:
      case ShaderMorphTriggerMode.onBuildForward:
        return;
      case ShaderMorphTriggerMode.tapToggle:
        unawaited(_toggle());
        return;
      case ShaderMorphTriggerMode.tapForward:
        unawaited(_forward());
        return;
      case ShaderMorphTriggerMode.tapReverse:
        unawaited(_reverse());
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final handle = ShaderMorphHandle(_forward, _reverse, _toggle);
    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: _destinationVisible ? 1.0 : 0.01,
          child: ShaderMorphCaptureLayer(
            boundaryKey: _destinationPaintKey,
            shadowCapturePolicy: widget.shadowCapturePolicy,
            captureChild: widget.destinationCapture,
            child: widget.destination,
          ),
        ),
        const Divider(height: 50),
        Opacity(
          opacity: _sourceVisible ? 1.0 : 0.0,
          child: ShaderMorphCaptureLayer(
            boundaryKey: _sourcePaintKey,
            shadowCapturePolicy: widget.shadowCapturePolicy,
            captureChild: widget.sourceCapture,
            child: widget.source,
          ),
        ),
      ],
    );
    if (widget.triggerMode != ShaderMorphTriggerMode.manual &&
        widget.triggerMode != ShaderMorphTriggerMode.onBuildForward) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTapTrigger,
        child: content,
      );
    }
    final morphContent = content;
    if (widget.childBuilder != null) {
      content = _ShaderMorphScope(
        handle: handle,
        child: Builder(
          builder: (scopedContext) =>
              widget.childBuilder!(scopedContext, morphContent),
        ),
      );
    } else {
      content = _ShaderMorphScope(handle: handle, child: content);
    }
    return PopScope(
      canPop: _allowNextPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBackPop(result);
      },
      child: content,
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _effectiveController.detach(this);
    _effectiveController.setStateFromHost(MorphPlaybackState.disposed);
    _ownedController?.dispose();
    _controller.dispose();
    super.dispose();
  }
}

class _ShaderMorphCrossRouteScope extends StatefulWidget {
  final String tagId;
  final CrossRouteMorphController controller;
  final BackPopMode backPopMode;
  final Widget child;

  const _ShaderMorphCrossRouteScope({
    required this.tagId,
    required this.controller,
    required this.backPopMode,
    required this.child,
  });

  @override
  State<_ShaderMorphCrossRouteScope> createState() =>
      _ShaderMorphCrossRouteScopeState();
}

class _ShaderMorphCrossRouteScopeState
    extends State<_ShaderMorphCrossRouteScope> {
  bool _handling = false;

  @override
  void dispose() {
    // Controller lifecycle is managed after reverse+pop completion.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.backPopMode == BackPopMode.immediatePopReset) {
      return widget.child;
    }
    return PopScope(
      canPop: !widget.controller.canReverse(widget.tagId),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _handling) return;
        _handling = true;
        final navigator = Navigator.of(context);
        try {
          final started = await widget.controller.playReverseDuringPop(
            context: context,
            tagId: widget.tagId,
            result: result,
          );
          if (!started && navigator.mounted) {
            navigator.maybePop(result);
          }
          ShaderMorph._releaseRouteController(widget.tagId, widget.controller);
        } finally {
          _handling = false;
        }
      },
      child: widget.child,
    );
  }
}

class _InternalMorphPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ui.FragmentShader? v1Shader;
  final ui.FragmentShader? v2ShadowShader;
  final ui.FragmentShader? v2RenderShader;
  final bool useV2Render;
  final MorphTransitionConfig transitionConfig;
  final MorphPairSnapshot snapshot;
  final double time;
  final double progress;

  _InternalMorphPainter({
    required this.shader,
    required this.v1Shader,
    required this.v2ShadowShader,
    required this.v2RenderShader,
    required this.useV2Render,
    required this.transitionConfig,
    required this.snapshot,
    required this.time,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shapedProgress = transitionConfig.transformProgress(progress);
    final metadata = MorphCoordinator.buildSinglePairMetadataV2(
      logicalViewport: size,
      sourceRect: snapshot.source,
      targetRect: snapshot.destination,
      progress: shapedProgress,
      morphStyle: transitionConfig.shaderStyleIndex,
      // RuntimeEffect fragment coordinates are logical-canvas space.
      usePhysicalResolution: false,
    );

    if (v2ShadowShader != null) {
      MorphCoordinator.setUniformsV2Packed(
        shader: v2ShadowShader!,
        metadata: metadata,
      );
      v2ShadowShader!.setImageSampler(0, snapshot.source.image);
      v2ShadowShader!.setImageSampler(1, snapshot.destination.image);
    }
    if (useV2Render && v2RenderShader != null) {
      MorphCoordinator.setUniformsV2Packed(
        shader: v2RenderShader!,
        metadata: metadata,
      );
      v2RenderShader!.setImageSampler(0, snapshot.source.image);
      v2RenderShader!.setImageSampler(1, snapshot.destination.image);
      canvas.drawRect(Offset.zero & size, Paint()..shader = v2RenderShader);
      return;
    }

    // Deprecated emergency fallback path. Remove after V2 stabilization window.
    final fallbackShader = v1Shader ?? shader;
    MorphCoordinator.setUniforms(
      shader: fallbackShader,
      viewport: size,
      sourceRect: snapshot.source,
      targetRect: snapshot.destination,
      time: time,
      progress: shapedProgress,
    );
    canvas.drawRect(Offset.zero & size, Paint()..shader = fallbackShader);
  }

  @override
  bool shouldRepaint(covariant _InternalMorphPainter oldDelegate) => true;
}
