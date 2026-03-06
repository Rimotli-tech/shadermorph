import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../models.dart';
import '../tracker.dart';
import '../coordinator.dart';
import '../cross_route.dart';
import '../runtime_config.dart';
import '../shader_program_cache.dart';
import '../transition_config.dart';

enum ShaderMorphRole { origin, destination }

enum ShaderMorphTrigger { none, onTapForward, onTapReverse }

enum BackPopMode { reverseThenPop, immediatePopReset }

abstract class ShaderMorphHostController {
  Future<bool> forwardByTag(String id);
  Future<bool> reverseByTag(String id);
}

class _ShaderMorphHostScope extends InheritedWidget {
  final _ShaderMorphHostControllerImpl controller;

  const _ShaderMorphHostScope({required this.controller, required super.child});

  static _ShaderMorphHostScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ShaderMorphHostScope>();
  }

  @override
  bool updateShouldNotify(covariant _ShaderMorphHostScope oldWidget) =>
      oldWidget.controller != controller;
}

class _TagEndpointEntry {
  final GlobalKey key;
  final MorphShadowCapturePolicy shadowCapturePolicy;

  const _TagEndpointEntry({
    required this.key,
    required this.shadowCapturePolicy,
  });
}

class _TagBuckets {
  final List<_TagEndpointEntry> origins = <_TagEndpointEntry>[];
  final List<_TagEndpointEntry> destinations = <_TagEndpointEntry>[];
}

class _ResolvedTagPair {
  final _TagEndpointEntry origin;
  final _TagEndpointEntry destination;

  const _ResolvedTagPair({required this.origin, required this.destination});
}

class _ShaderMorphHostControllerImpl implements ShaderMorphHostController {
  final _ShaderMorphHostState _state;
  final ValueNotifier<Set<GlobalKey>> hiddenKeys =
      ValueNotifier<Set<GlobalKey>>(<GlobalKey>{});
  final ValueNotifier<Map<String, bool>> destinationVisibleByTag =
      ValueNotifier<Map<String, bool>>(<String, bool>{});

  _ShaderMorphHostControllerImpl(this._state);

  @override
  Future<bool> forwardByTag(String id) =>
      _state._playByTag(id: id, direction: MorphDirection.forward);

  @override
  Future<bool> reverseByTag(String id) =>
      _state._playByTag(id: id, direction: MorphDirection.reverse);

  void registerTag({
    required String id,
    required ShaderMorphRole role,
    required GlobalKey key,
    required MorphShadowCapturePolicy shadowCapturePolicy,
  }) {
    _state._registerTag(
      id: id,
      role: role,
      key: key,
      shadowCapturePolicy: shadowCapturePolicy,
    );
  }

  void unregisterTag({
    required String id,
    required ShaderMorphRole role,
    required GlobalKey key,
  }) {
    _state._unregisterTag(id: id, role: role, key: key);
  }

  void hideKey(GlobalKey key) {
    final next = Set<GlobalKey>.from(hiddenKeys.value)..add(key);
    hiddenKeys.value = next;
  }

  void unhideKey(GlobalKey key) {
    final next = Set<GlobalKey>.from(hiddenKeys.value)..remove(key);
    hiddenKeys.value = next;
  }

  bool isDestinationVisible(String id) =>
      destinationVisibleByTag.value[id] ?? false;

  void setDestinationVisible({required String id, required bool visible}) {
    final next = Map<String, bool>.from(destinationVisibleByTag.value);
    if (visible) {
      next[id] = true;
    } else {
      next.remove(id);
    }
    destinationVisibleByTag.value = next;
  }
}

class ShaderMorphHost extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final MorphTransitionConfig transitionConfig;
  final MorphShadowCapturePolicy shadowCapturePolicy;
  final BackPopMode backPopMode;

  const ShaderMorphHost({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 800),
    this.transitionConfig = const MorphTransitionConfig(),
    this.shadowCapturePolicy = MorphShadowCapturePolicy.exclude,
    this.backPopMode = BackPopMode.reverseThenPop,
  });

  static ShaderMorphHostController of(BuildContext context) {
    final scope = _ShaderMorphHostScope.maybeOf(context);
    if (scope == null) {
      throw FlutterError(
        'ShaderMorphHost.of(context) called with no ShaderMorphHost ancestor.',
      );
    }
    return scope.controller;
  }

  @override
  State<ShaderMorphHost> createState() => _ShaderMorphHostState();
}

class _ShaderMorphHostState extends State<ShaderMorphHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final _ShaderMorphHostControllerImpl _hostController;
  final Map<String, _TagBuckets> _tags = <String, _TagBuckets>{};
  OverlayEntry? _overlayEntry;
  MorphPairSnapshot? _snapshot;
  final Set<GlobalKey> _hiddenKeys = <GlobalKey>{};
  ui.FragmentProgram? _program;
  ui.FragmentProgram? _v1Program;
  ui.FragmentShader? _v2ShadowShader;
  ui.FragmentShader? _v2RenderShader;
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _hostController = _ShaderMorphHostControllerImpl(this);
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _loadShader();
  }

  @override
  void didUpdateWidget(covariant ShaderMorphHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
  }

  void _registerTag({
    required String id,
    required ShaderMorphRole role,
    required GlobalKey key,
    required MorphShadowCapturePolicy shadowCapturePolicy,
  }) {
    final bucket = _tags.putIfAbsent(id, () => _TagBuckets());
    final target = role == ShaderMorphRole.origin
        ? bucket.origins
        : bucket.destinations;
    if (target.any((entry) => identical(entry.key, key))) {
      return;
    }
    target.add(
      _TagEndpointEntry(key: key, shadowCapturePolicy: shadowCapturePolicy),
    );
  }

  void _unregisterTag({
    required String id,
    required ShaderMorphRole role,
    required GlobalKey key,
  }) {
    final bucket = _tags[id];
    if (bucket == null) return;
    final target = role == ShaderMorphRole.origin
        ? bucket.origins
        : bucket.destinations;
    target.removeWhere((entry) => identical(entry.key, key));
    if (bucket.origins.isEmpty && bucket.destinations.isEmpty) {
      _tags.remove(id);
    }
    _hostController.unhideKey(key);
  }

  List<_TagEndpointEntry> _mountedEntries(List<_TagEndpointEntry> entries) {
    return entries
        .where((entry) => entry.key.currentContext?.findRenderObject() != null)
        .toList(growable: false);
  }

  _ResolvedTagPair? _resolveStrictPair(String id) {
    final bucket = _tags[id];
    if (bucket == null) return null;
    final mountedOrigins = _mountedEntries(bucket.origins);
    final mountedDestinations = _mountedEntries(bucket.destinations);
    if (mountedOrigins.length != 1 || mountedDestinations.length != 1) {
      debugPrint(
        'ShaderMorphHost: tag "$id" requires exactly one mounted origin and '
        'one mounted destination. Found origin=${mountedOrigins.length}, '
        'destination=${mountedDestinations.length}.',
      );
      return null;
    }
    return _ResolvedTagPair(
      origin: mountedOrigins.single,
      destination: mountedDestinations.single,
    );
  }

  Future<bool> _playByTag({
    required String id,
    required MorphDirection direction,
  }) async {
    if (!mounted) {
      debugPrint('ShaderMorphHost: play ignored; host is not mounted.');
      return false;
    }
    if (_animating) {
      debugPrint('ShaderMorphHost: play ignored; animation already active.');
      return false;
    }
    final destinationVisible = _hostController.isDestinationVisible(id);
    if (direction == MorphDirection.forward && destinationVisible) {
      debugPrint(
        'ShaderMorphHost: forward ignored for "$id"; destination already visible.',
      );
      return false;
    }
    if (direction == MorphDirection.reverse && !destinationVisible) {
      debugPrint(
        'ShaderMorphHost: reverse ignored for "$id"; origin already visible.',
      );
      return false;
    }
    final pair = _resolveStrictPair(id);
    if (pair == null) {
      debugPrint(
        'ShaderMorphHost: play failed for "$id"; unresolved tag pair.',
      );
      return false;
    }
    if (_program == null) {
      await _loadShader();
    }
    if (!mounted) {
      debugPrint('ShaderMorphHost: play aborted after shader load; unmounted.');
      return false;
    }
    if (_program == null) {
      // Graceful fallback for platforms/devices where runtime shaders are unavailable.
      debugPrint(
        'ShaderMorphHost: shader unavailable; applying instant state swap for "$id".',
      );
      _hostController.setDestinationVisible(
        id: id,
        visible: direction == MorphDirection.forward,
      );
      return true;
    }

    final originEndpoint = direction == MorphDirection.forward
        ? pair.origin
        : pair.destination;
    final destinationEndpoint = direction == MorphDirection.forward
        ? pair.destination
        : pair.origin;
    final hideKeys = <GlobalKey>{pair.origin.key, pair.destination.key};
    MorphSnapshot? originSnapshot;
    MorphSnapshot? destinationSnapshot;

    var success = false;
    try {
      originSnapshot = await MorphTracker.capture(
        originEndpoint.key,
        options: MorphCaptureOptions(
          shadowPolicy: originEndpoint.shadowCapturePolicy,
        ),
      );
      destinationSnapshot = await MorphTracker.capture(
        destinationEndpoint.key,
        options: MorphCaptureOptions(
          shadowPolicy: destinationEndpoint.shadowCapturePolicy,
        ),
      );
      if (!mounted) return false;
      for (final key in hideKeys) {
        _hiddenKeys.add(key);
        _hostController.hideKey(key);
      }
      _snapshot = MorphPairSnapshot(
        origin: originSnapshot,
        destination: destinationSnapshot,
      );
      originSnapshot = null;
      destinationSnapshot = null;
      _animating = true;
      _showOverlay();
      await _controller.forward(from: 0.0);
      success = true;
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'ShaderMorphHost: play failed for "$id"; '
        'capture/animation error: $error',
      );
      debugPrint('$stackTrace');
      return false;
    } finally {
      _cleanupTransition();
      if (success) {
        _hostController.setDestinationVisible(
          id: id,
          visible: direction == MorphDirection.forward,
        );
      }
      originSnapshot?.dispose();
      destinationSnapshot?.dispose();
    }
  }

  Future<void> _loadShader() async {
    try {
      final bundle = await ShaderMorphProgramCache.loadOrGet();
      if (bundle == null) {
        debugPrint('ShaderMorphHost: Failed to load shader.');
        return;
      }
      final v1Prog = bundle.v1Program;
      final v2Prog = bundle.v2Program;

      final config = MorphRuntimeConfig.current;
      maybeLogRuntimeDeprecations(config);

      ui.FragmentShader? shadowShader;
      if (config.enableV2ShadowBindWhenV1 && v2Prog != null) {
        shadowShader = v2Prog.fragmentShader();
      }
      final renderShader = config.useV2SinglePageRender && v2Prog != null
          ? v2Prog.fragmentShader()
          : null;

      _v1Program = v1Prog;
      _v2ShadowShader = shadowShader;
      _v2RenderShader = renderShader;
      if (mounted) {
        setState(() {
          _program = v2Prog ?? v1Prog;
        });
      } else {
        _program = v2Prog ?? v1Prog;
      }
    } catch (_) {
      debugPrint('ShaderMorphHost: Failed to load shader.');
    }
  }

  void _showOverlay() {
    final snapshot = _snapshot;
    final program = _program;
    if (snapshot == null || program == null) {
      return;
    }
    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _InternalMorphPainter(
                  shader: program.fragmentShader(),
                  v1Shader: _v1Program?.fragmentShader(),
                  v2ShadowShader: _v2ShadowShader,
                  v2RenderShader: _v2RenderShader,
                  useV2Render: MorphRuntimeConfig.current.useV2SinglePageRender,
                  transitionConfig: widget.transitionConfig,
                  snapshot: snapshot,
                  time: _controller.value * 6.28,
                  progress: _controller.value,
                ),
              );
            },
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  void _cleanupTransition() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _snapshot?.dispose();
    _snapshot = null;
    _controller.stop();
    _controller.reset();
    for (final hiddenKey in _hiddenKeys) {
      _hostController.unhideKey(hiddenKey);
    }
    _hiddenKeys.clear();
    _animating = false;
  }

  @override
  Widget build(BuildContext context) {
    return _ShaderMorphHostScope(
      controller: _hostController,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _cleanupTransition();
    _hostController.hiddenKeys.dispose();
    _hostController.destinationVisibleByTag.dispose();
    _controller.dispose();
    super.dispose();
  }
}

class ShaderMorphTag extends StatefulWidget {
  final String id;
  final ShaderMorphRole role;
  final Widget? captureChild;
  final MorphShadowCapturePolicy shadowCapturePolicy;
  final ShaderMorphTrigger trigger;
  final Widget child;

  const ShaderMorphTag({
    super.key,
    required this.id,
    required this.role,
    this.captureChild,
    this.shadowCapturePolicy = MorphShadowCapturePolicy.exclude,
    this.trigger = ShaderMorphTrigger.none,
    required this.child,
  });

  @override
  State<ShaderMorphTag> createState() => _ShaderMorphTagState();
}

class _ShaderMorphTagState extends State<ShaderMorphTag> {
  final GlobalKey _paintKey = GlobalKey();
  _ShaderMorphHostControllerImpl? _hostController;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextHost = _ShaderMorphHostScope.maybeOf(context)?.controller;
    if (identical(_hostController, nextHost)) {
      return;
    }
    _unregisterFromHost();
    _hostController = nextHost;
    _registerToHost();
  }

  @override
  void didUpdateWidget(covariant ShaderMorphTag oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id ||
        oldWidget.role != widget.role ||
        oldWidget.shadowCapturePolicy != widget.shadowCapturePolicy) {
      _unregisterFromHost(id: oldWidget.id, role: oldWidget.role);
      _registerToHost();
    }
  }

  void _registerToHost() {
    _hostController?.registerTag(
      id: widget.id,
      role: widget.role,
      key: _paintKey,
      shadowCapturePolicy: widget.shadowCapturePolicy,
    );
  }

  void _unregisterFromHost({String? id, ShaderMorphRole? role}) {
    _hostController?.unregisterTag(
      id: id ?? widget.id,
      role: role ?? widget.role,
      key: _paintKey,
    );
  }

  @override
  void dispose() {
    _unregisterFromHost();
    super.dispose();
  }

  void _handleTagTrigger() {
    final controller = _hostController;
    if (controller == null) return;
    switch (widget.trigger) {
      case ShaderMorphTrigger.none:
        return;
      case ShaderMorphTrigger.onTapForward:
        unawaited(controller.forwardByTag(widget.id));
        return;
      case ShaderMorphTrigger.onTapReverse:
        unawaited(controller.reverseByTag(widget.id));
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = ShaderMorphCaptureLayer(
      boundaryKey: _paintKey,
      shadowCapturePolicy: widget.shadowCapturePolicy,
      captureChild: widget.captureChild,
      child: widget.child,
    );
    final controller = _hostController;
    if (controller != null) {
      content = AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[
          controller.hiddenKeys,
          controller.destinationVisibleByTag,
        ]),
        builder: (context, child) {
          final hiddenByLifecycle = controller.hiddenKeys.value.contains(
            _paintKey,
          );
          final destinationVisible = controller.isDestinationVisible(widget.id);
          final hiddenByPhase = widget.role == ShaderMorphRole.destination
              ? !destinationVisible
              : destinationVisible;
          final hidden = hiddenByLifecycle || hiddenByPhase;
          if (!hidden) {
            return child!;
          }
          return IgnorePointer(
            child: ExcludeSemantics(
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix(_transparentColorMatrix),
                child: child,
              ),
            ),
          );
        },
        child: content,
      );
    }
    if (widget.trigger != ShaderMorphTrigger.none) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTagTrigger,
        child: content,
      );
    }
    return content;
  }
}

class ShaderMorph {
  ShaderMorph._();

  static final Map<String, ShaderMorphCrossRouteEngine> _routeControllers =
      <String, ShaderMorphCrossRouteEngine>{};

  static Widget tag({
    required String id,
    required Widget child,
    Widget? captureChild,
    MorphShadowCapturePolicy shadowCapturePolicy =
        MorphShadowCapturePolicy.exclude,
  }) {
    return CrossRouteMorphTag(
      id: id,
      captureChild: captureChild,
      shadowCapturePolicy: shadowCapturePolicy,
      child: child,
    );
  }

  /// Preloads shader programs to reduce first-use compile jank.
  static Future<void> prewarm() async {
    await ShaderMorphProgramCache.prewarm();
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
    final engine = ShaderMorphCrossRouteEngine(
      transitionConfig: transitionConfig,
      shadowCapturePolicy: shadowCapturePolicy,
    );
    _routeControllers[tagId]?.dispose();
    _routeControllers[tagId] = engine;
    final wrappedPage = _ShaderMorphCrossRouteScope(
      tagId: tagId,
      engine: engine,
      backPopMode: backPopMode,
      child: page,
    );
    return engine.startToRoute(
      context: context,
      tagId: tagId,
      route: _buildRoute(
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
    final engine = _routeControllers[tagId];
    if (engine == null) {
      if (context.mounted) {
        Navigator.of(context).maybePop(result);
      }
      return false;
    }
    final ok = await engine.playReverseDuringPop(
      context: context,
      tagId: tagId,
      result: result,
      timeout: timeout,
    );
    if (!ok && context.mounted) {
      Navigator.of(context).maybePop(result);
    }
    _releaseRouteController(tagId, engine);
    return ok;
  }

  static void _releaseRouteController(
    String tagId,
    ShaderMorphCrossRouteEngine engine,
  ) {
    final active = _routeControllers[tagId];
    if (identical(active, engine)) {
      _routeControllers.remove(tagId);
    }
    engine.dispose();
  }
}

Route<void> _buildRoute({
  required Widget page,
  bool suppressTransition = true,
  RouteSettings? settings,
}) {
  if (!suppressTransition) {
    return MaterialPageRoute<void>(builder: (_) => page, settings: settings);
  }
  return PageRouteBuilder<void>(
    settings: settings,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return child;
    },
  );
}

class _ShaderMorphCrossRouteScope extends StatefulWidget {
  final String tagId;
  final ShaderMorphCrossRouteEngine engine;
  final BackPopMode backPopMode;
  final Widget child;

  const _ShaderMorphCrossRouteScope({
    required this.tagId,
    required this.engine,
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
      canPop: !widget.engine.canReverse(widget.tagId),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _handling) return;
        _handling = true;
        final navigator = Navigator.of(context);
        try {
          final started = await widget.engine.playReverseDuringPop(
            context: context,
            tagId: widget.tagId,
            result: result,
          );
          if (!started && navigator.mounted) {
            navigator.maybePop(result);
          }
          ShaderMorph._releaseRouteController(widget.tagId, widget.engine);
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
  static const double _paintBleedPx = 16.0;

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
      sourceRect: snapshot.origin,
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
      v2ShadowShader!.setImageSampler(0, snapshot.origin.image);
      v2ShadowShader!.setImageSampler(1, snapshot.destination.image);
    }
    if (useV2Render && v2RenderShader != null) {
      MorphCoordinator.setUniformsV2Packed(
        shader: v2RenderShader!,
        metadata: metadata,
      );
      v2RenderShader!.setImageSampler(0, snapshot.origin.image);
      v2RenderShader!.setImageSampler(1, snapshot.destination.image);
      final paintRegion = _computePaintRegion(size);
      if (paintRegion.isEmpty) {
        return;
      }
      canvas.drawRect(paintRegion, Paint()..shader = v2RenderShader);
      return;
    }

    // Deprecated emergency fallback path. Remove after V2 stabilization window.
    final fallbackShader = v1Shader ?? shader;
    MorphCoordinator.setUniforms(
      shader: fallbackShader,
      viewport: size,
      sourceRect: snapshot.origin,
      targetRect: snapshot.destination,
      time: time,
      progress: shapedProgress,
    );
    final paintRegion = _computePaintRegion(size);
    if (paintRegion.isEmpty) {
      return;
    }
    canvas.drawRect(paintRegion, Paint()..shader = fallbackShader);
  }

  Rect _computePaintRegion(Size viewportSize) {
    final union = snapshot.origin.rect.expandToInclude(
      snapshot.destination.rect,
    );
    final expanded = union.inflate(_paintBleedPx);
    final viewport = Offset.zero & viewportSize;
    return expanded.intersect(viewport);
  }

  @override
  bool shouldRepaint(covariant _InternalMorphPainter oldDelegate) => true;
}
