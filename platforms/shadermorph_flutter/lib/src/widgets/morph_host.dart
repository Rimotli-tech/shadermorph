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

enum ShaderMorphRole { source, destination }

enum ShaderMorphTrigger { none, onTapForward, onTapReverse }

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
  final List<_TagEndpointEntry> sources = <_TagEndpointEntry>[];
  final List<_TagEndpointEntry> destinations = <_TagEndpointEntry>[];
}

class _ResolvedTagPair {
  final _TagEndpointEntry source;
  final _TagEndpointEntry destination;

  const _ResolvedTagPair({required this.source, required this.destination});
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
  MorphDirection _activeDirection = MorphDirection.forward;
  GlobalKey? _hiddenKey;
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
    final target = role == ShaderMorphRole.source
        ? bucket.sources
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
    final target = role == ShaderMorphRole.source
        ? bucket.sources
        : bucket.destinations;
    target.removeWhere((entry) => identical(entry.key, key));
    if (bucket.sources.isEmpty && bucket.destinations.isEmpty) {
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
    final mountedSources = _mountedEntries(bucket.sources);
    final mountedDestinations = _mountedEntries(bucket.destinations);
    if (mountedSources.length != 1 || mountedDestinations.length != 1) {
      debugPrint(
        'ShaderMorphHost: tag "$id" requires exactly one mounted source and '
        'one mounted destination. Found source=${mountedSources.length}, '
        'destination=${mountedDestinations.length}.',
      );
      return null;
    }
    return _ResolvedTagPair(
      source: mountedSources.single,
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
        'ShaderMorphHost: reverse ignored for "$id"; source already visible.',
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

    final sourceEndpoint = direction == MorphDirection.forward
        ? pair.source
        : pair.destination;
    final destinationEndpoint = direction == MorphDirection.forward
        ? pair.destination
        : pair.source;
    final hideKey = direction == MorphDirection.forward
        ? pair.destination.key
        : pair.source.key;

    var success = false;
    try {
      final sourceSnapshot = await MorphTracker.capture(
        sourceEndpoint.key,
        options: MorphCaptureOptions(
          shadowPolicy: sourceEndpoint.shadowCapturePolicy,
        ),
      );
      final destinationSnapshot = await MorphTracker.capture(
        destinationEndpoint.key,
        options: MorphCaptureOptions(
          shadowPolicy: destinationEndpoint.shadowCapturePolicy,
        ),
      );
      if (!mounted) return false;
      _hiddenKey = hideKey;
      _hostController.hideKey(hideKey);
      _activeDirection = direction;
      _snapshot = MorphPairSnapshot(
        source: sourceSnapshot,
        destination: destinationSnapshot,
      );
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
    }
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
      } catch (_) {}

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
    _snapshot = null;
    _controller.stop();
    _controller.reset();
    final hiddenKey = _hiddenKey;
    if (hiddenKey != null) {
      _hostController.unhideKey(hiddenKey);
    }
    _hiddenKey = null;
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
