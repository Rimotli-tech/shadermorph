import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'coordinator.dart';
import 'models.dart';
import 'policy.dart';
import 'runtime_config.dart';
import 'shader_program_cache.dart';
import 'shape.dart';
import 'tracker.dart';
import 'transition_config.dart';

/// Lifecycle states for the internal cross-route morph engine.
enum CrossRouteMorphState {
  idle,
  capturedOrigin,
  animatingForward,
  atDestination,
  animatingReverse,
  disposed,
}

/// Cross-route tag widget used by [ShaderMorph.tag].
class CrossRouteMorphTag extends StatefulWidget {
  final String id;
  final MorphShadowCapturePolicy shadowCapturePolicy;
  final MorphShape shape;
  final Widget? captureChild;
  final Widget child;

  const CrossRouteMorphTag({
    super.key,
    required this.id,
    this.shadowCapturePolicy = MorphShadowCapturePolicy.include,
    this.shape = const MorphShape.rect(),
    this.captureChild,
    required this.child,
  });

  @override
  State<CrossRouteMorphTag> createState() => _CrossRouteMorphTagState();
}

class _CrossRouteMorphTagState extends State<CrossRouteMorphTag> {
  final GlobalKey _paintKey = GlobalKey();
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
    MorphTagRegistry.instance.register(
      widget.id,
      _paintKey,
      shape: widget.shape,
    );
  }

  @override
  void didUpdateWidget(covariant CrossRouteMorphTag oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id || oldWidget.shape != widget.shape) {
      MorphTagRegistry.instance.unregister(oldWidget.id, _paintKey);
      MorphTagRegistry.instance.register(
        widget.id,
        _paintKey,
        shape: widget.shape,
      );
    }
  }

  @override
  void dispose() {
    MorphTagRegistry.instance.unregister(widget.id, _paintKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<GlobalKey>>(
      valueListenable: MorphTagRegistry.instance.hiddenTags,
      builder: (context, hiddenTags, _) {
        return ValueListenableBuilder<Set<String>>(
          valueListenable: MorphTagRegistry.instance.hiddenTagIds,
          builder: (context, hiddenTagIds, _) {
            final hidden =
                hiddenTags.contains(_paintKey) ||
                hiddenTagIds.contains(widget.id);
            Widget content = ShaderMorphCaptureLayer(
              boundaryKey: _paintKey,
              shadowCapturePolicy: widget.shadowCapturePolicy,
              captureChild: widget.captureChild,
              child: widget.child,
            );
            if (!hidden) {
              return content;
            }
            return IgnorePointer(
              child: ExcludeSemantics(
                child: ColorFiltered(
                  colorFilter: const ColorFilter.matrix(
                    _transparentColorMatrix,
                  ),
                  child: content,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class MorphTagRegistry {
  MorphTagRegistry._();

  static final MorphTagRegistry instance = MorphTagRegistry._();

  final Map<String, List<GlobalKey>> _tags = <String, List<GlobalKey>>{};
  final Map<GlobalKey, MorphShape> _shapes = <GlobalKey, MorphShape>{};
  final ValueNotifier<Set<GlobalKey>> hiddenTags =
      ValueNotifier<Set<GlobalKey>>(<GlobalKey>{});
  final ValueNotifier<Set<String>> hiddenTagIds = ValueNotifier<Set<String>>(
    <String>{},
  );

  void register(
    String id,
    GlobalKey key, {
    MorphShape shape = const MorphShape.rect(),
  }) {
    final keys = _tags.putIfAbsent(id, () => <GlobalKey>[]);
    if (!keys.contains(key)) {
      keys.add(key);
    }
    _shapes[key] = shape;
  }

  void unregister(String id, GlobalKey key) {
    final keys = _tags[id];
    if (keys == null) return;
    keys.remove(key);
    _shapes.remove(key);
    if (keys.isEmpty) {
      _tags.remove(id);
    }
  }

  /// Returns the structural shape registered for [key].
  MorphShape shapeForKey(GlobalKey key) =>
      _shapes[key] ?? const MorphShape.rect();

  /// Returns the most recently mounted key for [id], if any.
  GlobalKey? keyFor(String id) => _latestMountedKey(id);

  /// Captures the latest mounted endpoint for [id].
  Future<MorphSnapshot?> captureById(
    String id, {
    MorphCaptureOptions options = const MorphCaptureOptions(
      shadowPolicy: MorphShadowCapturePolicy.include,
    ),
  }) async {
    final key = keyFor(id);
    if (key == null) return null;
    return captureByKey(key, options: options);
  }

  /// Captures a snapshot for a specific tag render key.
  Future<MorphSnapshot?> captureByKey(
    GlobalKey key, {
    MorphCaptureOptions options = const MorphCaptureOptions(
      shadowPolicy: MorphShadowCapturePolicy.include,
    ),
  }) async {
    try {
      return await MorphTracker.capture(key, options: options);
    } catch (_) {
      return null;
    }
  }

  GlobalKey? keyForExcluding(String id, GlobalKey excludedKey) {
    final keys = _tags[id];
    if (keys == null || keys.isEmpty) return null;
    for (var i = keys.length - 1; i >= 0; i -= 1) {
      final key = keys[i];
      if (identical(key, excludedKey)) continue;
      final mounted = key.currentContext?.findRenderObject() != null;
      if (mounted) return key;
    }
    for (var i = keys.length - 1; i >= 0; i -= 1) {
      final key = keys[i];
      if (!identical(key, excludedKey)) {
        return key;
      }
    }
    return null;
  }

  void setHiddenForKey(GlobalKey key, {required bool hidden}) {
    final updated = Set<GlobalKey>.from(hiddenTags.value);
    if (hidden) {
      updated.add(key);
    } else {
      updated.remove(key);
    }
    if (!setEquals(updated, hiddenTags.value)) {
      hiddenTags.value = updated;
    }
  }

  void setHiddenForId(String id, {required bool hidden}) {
    final updated = Set<String>.from(hiddenTagIds.value);
    if (hidden) {
      updated.add(id);
    } else {
      updated.remove(id);
    }
    if (!setEquals(updated, hiddenTagIds.value)) {
      hiddenTagIds.value = updated;
    }
  }

  @visibleForTesting
  void clearForTesting() {
    _tags.clear();
    _shapes.clear();
    hiddenTags.value = <GlobalKey>{};
    hiddenTagIds.value = <String>{};
  }

  GlobalKey? _latestMountedKey(String id) {
    final keys = _tags[id];
    if (keys == null || keys.isEmpty) return null;
    for (var i = keys.length - 1; i >= 0; i -= 1) {
      final key = keys[i];
      final mounted = key.currentContext?.findRenderObject() != null;
      if (mounted) return key;
    }
    return keys.last;
  }
}

class CrossRouteMorphSessionStore {
  String? tagId;
  MorphSnapshot? origin;
  MorphShape? originShape;
  int _token = 0;

  int nextToken() {
    _token += 1;
    return _token;
  }

  int get token => _token;

  /// Returns `true` when the store holds an active session for [id].
  bool hasSessionFor(String id) => origin != null && tagId == id;

  void setOrigin({
    required String id,
    required MorphSnapshot snapshot,
    required MorphShape shape,
  }) {
    origin?.dispose();
    tagId = id;
    origin = snapshot;
    originShape = shape;
    nextToken();
  }

  void clear() {
    origin?.dispose();
    tagId = null;
    origin = null;
    originShape = null;
    nextToken();
  }
}

/// Engine that coordinates capture, overlay playback, and route transitions.
class ShaderMorphCrossRouteEngine extends ChangeNotifier {
  final Duration duration;
  final MorphTransitionConfig transitionConfig;
  final MorphShadowCapturePolicy shadowCapturePolicy;
  final ShaderMorphPolicy policy;
  final MorphTagRegistry _registry;
  final CrossRouteMorphSessionStore _session;

  CrossRouteMorphState _state = CrossRouteMorphState.idle;
  ui.FragmentProgram? _program;
  // Deprecated emergency fallback path. Remove after V2 stabilization window.
  ui.FragmentProgram? _v1Program;
  ui.FragmentShader? _v2ShadowShader;
  ui.FragmentShader? _v2RenderShader;
  OverlayEntry? _overlayEntry;
  Ticker? _ticker;
  _CrossRouteVisualState? _visualState;

  ShaderMorphCrossRouteEngine({
    this.duration = const Duration(milliseconds: 800),
    this.transitionConfig = const MorphTransitionConfig(),
    this.shadowCapturePolicy = MorphShadowCapturePolicy.include,
    this.policy = const ShaderMorphPolicy.always(),
    MorphTagRegistry? registry,
    CrossRouteMorphSessionStore? session,
  }) : _registry = registry ?? MorphTagRegistry.instance,
       _session = session ?? CrossRouteMorphSessionStore();

  MorphCaptureOptions get _captureOptions =>
      MorphCaptureOptions(shadowPolicy: shadowCapturePolicy);

  /// Current engine state.
  CrossRouteMorphState get state => _state;

  /// Whether a forward or reverse morph is currently running.
  bool get isAnimating =>
      _state == CrossRouteMorphState.animatingForward ||
      _state == CrossRouteMorphState.animatingReverse;

  /// Whether a reverse morph can currently be started for [tagId].
  bool canReverse(String tagId) =>
      _state == CrossRouteMorphState.atDestination &&
      _session.hasSessionFor(tagId);

  /// Starts a forward morph while pushing [route].
  Future<bool> startToRoute({
    required BuildContext context,
    required String tagId,
    required Route<void> route,
  }) async {
    if (_state == CrossRouteMorphState.disposed || isAnimating) return false;
    if (!policy.allowsAnimation) {
      if (!context.mounted) return false;
      unawaited(Navigator.of(context).push(route));
      return true;
    }

    final originKey = _registry.keyFor(tagId);
    if (originKey == null) return false;
    final originShape = _registry.shapeForKey(originKey);
    final originSnapshot = await _registry.captureByKey(
      originKey,
      options: _captureOptions,
    );
    if (originSnapshot == null) return false;
    if (!context.mounted) return false;
    final navigator = Navigator.of(context);
    final overlayState = Overlay.of(context, rootOverlay: true);
    final program = await _loadProgram();
    if (program == null || !overlayState.mounted) return false;

    _session.setOrigin(id: tagId, snapshot: originSnapshot, shape: originShape);
    MorphSnapshot? transientDestination;
    final expectedToken = _session.token;
    GlobalKey? destinationKey;
    var success = false;
    try {
      // Hide origin endpoint before route push to avoid double-draw on source page.
      _registry.setHiddenForKey(originKey, hidden: true);
      // Hide any same-id endpoint immediately on route mount to avoid first-frame flash.
      _registry.setHiddenForId(tagId, hidden: true);
      _setState(CrossRouteMorphState.capturedOrigin);

      _showOverlay(
        overlayState: overlayState,
        program: program,
        source: originSnapshot,
        destination: originSnapshot,
        sourceShape: originShape,
        targetShape: originShape,
        direction: MorphDirection.forward,
        progress: 0.0,
      );

      unawaited(navigator.push(route));
      destinationKey = await _waitForTargetKey(
        tagId,
        excludedKey: originKey,
        timeout: const Duration(seconds: 3),
      );
      if (destinationKey == null || _session.token != expectedToken) {
        _setState(CrossRouteMorphState.idle);
        return false;
      }
      final destinationShape = _registry.shapeForKey(destinationKey);
      final destinationSnapshot = await _waitForStableSnapshotByKey(
        destinationKey,
        timeout: const Duration(seconds: 3),
      );
      if (destinationSnapshot == null || _session.token != expectedToken) {
        _setState(CrossRouteMorphState.idle);
        return false;
      }
      transientDestination = destinationSnapshot;

      _registry.setHiddenForKey(destinationKey, hidden: true);
      _setState(CrossRouteMorphState.animatingForward);
      _visualState?.setDestination(destinationSnapshot, destinationShape);

      final completed = await _animateOverlay(
        direction: MorphDirection.forward,
        expectedToken: expectedToken,
      );
      _setState(
        completed
            ? CrossRouteMorphState.atDestination
            : CrossRouteMorphState.idle,
      );
      success = completed;
      return success;
    } finally {
      _removeOverlay();
      _registry.setHiddenForId(tagId, hidden: false);
      _registry.setHiddenForKey(originKey, hidden: false);
      if (destinationKey != null) {
        _registry.setHiddenForKey(destinationKey, hidden: false);
      }
      transientDestination?.dispose();
      if (!success) {
        _session.clear();
      }
    }
  }

  Future<bool> playForward({
    required BuildContext context,
    required String tagId,
  }) async {
    if (_state == CrossRouteMorphState.disposed || isAnimating) return false;
    if (!_session.hasSessionFor(tagId)) return false;
    final origin = _session.origin;
    if (origin == null) return false;
    final originShape = _session.originShape ?? const MorphShape.rect();
    final destinationKey = _registry.keyFor(tagId);
    if (destinationKey == null) return false;
    final destinationShape = _registry.shapeForKey(destinationKey);

    final destination = await _registry.captureByKey(
      destinationKey,
      options: _captureOptions,
    );
    if (destination == null) return false;
    if (!context.mounted) return false;
    final overlayState = Overlay.of(context, rootOverlay: true);

    _setState(CrossRouteMorphState.animatingForward);
    _registry.setHiddenForKey(destinationKey, hidden: true);
    try {
      final ok = await _runOverlayAnimation(
        overlayState: overlayState,
        source: origin,
        destination: destination,
        sourceShape: originShape,
        targetShape: destinationShape,
        direction: MorphDirection.forward,
        expectedToken: _session.token,
      );
      _setState(
        ok ? CrossRouteMorphState.atDestination : CrossRouteMorphState.idle,
      );
      return ok;
    } finally {
      _registry.setHiddenForKey(destinationKey, hidden: false);
      destination.dispose();
    }
  }

  Future<bool> playReverse({
    required BuildContext context,
    required String tagId,
  }) async {
    if (_state == CrossRouteMorphState.disposed || isAnimating) return false;
    if (!_session.hasSessionFor(tagId)) return false;
    if (_state != CrossRouteMorphState.atDestination) return false;

    final origin = _session.origin;
    if (origin == null) return false;
    final originShape = _session.originShape ?? const MorphShape.rect();
    final destinationKey = _registry.keyFor(tagId);
    if (destinationKey == null) return false;
    final destinationShape = _registry.shapeForKey(destinationKey);
    final currentDestination = await _registry.captureByKey(
      destinationKey,
      options: _captureOptions,
    );
    if (currentDestination == null) return false;
    if (!context.mounted) return false;
    final overlayState = Overlay.of(context, rootOverlay: true);

    _setState(CrossRouteMorphState.animatingReverse);
    _registry.setHiddenForKey(destinationKey, hidden: true);
    try {
      final ok = await _runOverlayAnimation(
        overlayState: overlayState,
        source: currentDestination,
        destination: origin,
        sourceShape: destinationShape,
        targetShape: originShape,
        direction: MorphDirection.reverse,
        expectedToken: _session.token,
      );
      _setState(
        ok
            ? CrossRouteMorphState.capturedOrigin
            : CrossRouteMorphState.atDestination,
      );
      return ok;
    } finally {
      _registry.setHiddenForKey(destinationKey, hidden: false);
      currentDestination.dispose();
    }
  }

  Future<bool> playReverseDuringPop({
    required BuildContext context,
    required String tagId,
    Object? result,
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    if (_state == CrossRouteMorphState.disposed || isAnimating) return false;
    if (!_session.hasSessionFor(tagId)) return false;
    if (_state != CrossRouteMorphState.atDestination) return false;
    final origin = _session.origin;
    if (origin == null) return false;
    final originShape = _session.originShape ?? const MorphShape.rect();

    final destinationKey = _registry.keyFor(tagId);
    if (destinationKey == null) return false;
    final destinationShape = _registry.shapeForKey(destinationKey);
    final destinationSnapshot = await _registry.captureByKey(
      destinationKey,
      options: _captureOptions,
    );
    if (destinationSnapshot == null) return false;
    if (!context.mounted) return false;
    final overlayState = Overlay.of(context, rootOverlay: true);
    final program = await _loadProgram();
    if (program == null || !overlayState.mounted) return false;
    if (!context.mounted) return false;
    final navigator = Navigator.of(context);
    final originKey = _registry.keyForExcluding(tagId, destinationKey);
    final expectedToken = _session.token;

    _registry.setHiddenForKey(destinationKey, hidden: true);
    _registry.setHiddenForId(tagId, hidden: true);
    if (originKey != null) {
      _registry.setHiddenForKey(originKey, hidden: true);
    }
    _setState(CrossRouteMorphState.animatingReverse);

    bool completed = false;
    try {
      _showOverlay(
        overlayState: overlayState,
        program: program,
        source: destinationSnapshot,
        destination: origin,
        sourceShape: destinationShape,
        targetShape: originShape,
        direction: MorphDirection.reverse,
        progress: 0.0,
      );

      if (navigator.mounted) {
        unawaited(navigator.maybePop(result));
      }

      completed = await _animateOverlay(
        direction: MorphDirection.reverse,
        expectedToken: expectedToken,
      ).timeout(timeout, onTimeout: () => false);
    } finally {
      _removeOverlay();
      destinationSnapshot.dispose();
      _registry.setHiddenForId(tagId, hidden: false);
      _registry.setHiddenForKey(destinationKey, hidden: false);
      if (originKey != null) {
        _registry.setHiddenForKey(originKey, hidden: false);
      }
      _setState(
        completed
            ? CrossRouteMorphState.capturedOrigin
            : CrossRouteMorphState.idle,
      );
    }
    return true;
  }

  Future<bool> playReverseBeforePop({
    required BuildContext context,
    required String tagId,
    Object? result,
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    return playReverseDuringPop(
      context: context,
      tagId: tagId,
      result: result,
      timeout: timeout,
    );
  }

  Future<bool> _runOverlayAnimation({
    required OverlayState overlayState,
    required MorphSnapshot source,
    required MorphSnapshot destination,
    required MorphShape sourceShape,
    required MorphShape targetShape,
    required MorphDirection direction,
    required int expectedToken,
  }) async {
    final program = await _loadProgram();
    if (program == null) return false;
    if (overlayState.mounted == false) return false;

    try {
      _showOverlay(
        overlayState: overlayState,
        program: program,
        source: source,
        destination: destination,
        sourceShape: sourceShape,
        targetShape: targetShape,
        direction: direction,
        progress: 0.0,
      );
      return await _animateOverlay(
        direction: direction,
        expectedToken: expectedToken,
      );
    } finally {
      _removeOverlay();
    }
  }

  void _finishAnimation(bool success, Completer<bool> completer) {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    if (!completer.isCompleted) {
      completer.complete(success);
    }
  }

  void _showOverlay({
    required OverlayState overlayState,
    required ui.FragmentProgram program,
    required MorphSnapshot source,
    required MorphSnapshot destination,
    required MorphShape sourceShape,
    required MorphShape targetShape,
    required MorphDirection direction,
    required double progress,
  }) {
    _removeOverlay();
    _visualState = _CrossRouteVisualState(
      source: source,
      destination: destination,
      sourceShape: sourceShape,
      targetShape: targetShape,
      direction: direction,
      progress: progress,
    );
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _visualState!,
            builder: (context, _) {
              final state = _visualState!;
              return CustomPaint(
                painter: _CrossRouteMorphPainter(
                  shader: program.fragmentShader(),
                  v1Shader: _v1Program?.fragmentShader(),
                  v2ShadowShader: _v2ShadowShader,
                  v2RenderShader: _v2RenderShader,
                  useV2Render: MorphRuntimeConfig.current.useV2CrossRouteRender,
                  transitionConfig: transitionConfig,
                  source: state.source,
                  destination: state.destination,
                  sourceShape: state.sourceShape,
                  targetShape: state.targetShape,
                  progress: state.progress,
                  direction: state.direction,
                ),
              );
            },
          ),
        ),
      ),
    );
    overlayState.insert(_overlayEntry!);
  }

  Future<bool> _animateOverlay({
    required MorphDirection direction,
    required int expectedToken,
  }) async {
    final visual = _visualState;
    if (visual == null) return false;
    final completer = Completer<bool>();
    _ticker?.dispose();
    _ticker = Ticker((elapsed) {
      if (_state == CrossRouteMorphState.disposed ||
          _session.token != expectedToken) {
        _finishAnimation(false, completer);
        return;
      }
      final raw = elapsed.inMicroseconds / duration.inMicroseconds;
      final clamped = raw.clamp(0.0, 1.0);
      visual.setDirection(direction);
      visual.setProgress(clamped);
      if (clamped >= 1.0) {
        _finishAnimation(true, completer);
      }
    });
    _ticker?.start();
    return completer.future;
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _visualState = null;
  }

  Future<GlobalKey?> _waitForTargetKey(
    String tagId, {
    required GlobalKey excludedKey,
    required Duration timeout,
  }) async {
    final sw = Stopwatch()..start();
    while (sw.elapsed < timeout && _state != CrossRouteMorphState.disposed) {
      await SchedulerBinding.instance.endOfFrame;
      final key = _registry.keyForExcluding(tagId, excludedKey);
      if (key != null) {
        return key;
      }
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    return null;
  }

  Future<MorphSnapshot?> _waitForStableSnapshotByKey(
    GlobalKey key, {
    required Duration timeout,
    int consecutiveStableFrames = 3,
    double rectEpsilonPx = 0.5,
  }) async {
    final sw = Stopwatch()..start();
    MorphSnapshot? previous;
    var stableFrames = 0;
    try {
      while (sw.elapsed < timeout && _state != CrossRouteMorphState.disposed) {
        await SchedulerBinding.instance.endOfFrame;
        final snapshot = await _registry.captureByKey(
          key,
          options: _captureOptions,
        );
        if (snapshot != null) {
          final isStable =
              previous != null &&
              _isRectStable(
                previous.rect,
                snapshot.rect,
                epsilon: rectEpsilonPx,
              );
          stableFrames = isStable ? stableFrames + 1 : 1;
          if (stableFrames >= consecutiveStableFrames) {
            previous?.dispose();
            previous = null;
            return snapshot;
          }
          previous?.dispose();
          previous = snapshot;
        } else {
          stableFrames = 0;
        }
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
    } finally {
      previous?.dispose();
    }
    return null;
  }

  bool _isRectStable(Rect a, Rect b, {required double epsilon}) {
    return (a.left - b.left).abs() <= epsilon &&
        (a.top - b.top).abs() <= epsilon &&
        (a.width - b.width).abs() <= epsilon &&
        (a.height - b.height).abs() <= epsilon;
  }

  Future<ui.FragmentProgram?> _loadProgram() async {
    if (_program != null) return _program;
    try {
      final bundle = await ShaderMorphProgramCache.loadOrGet();
      if (bundle == null) {
        return null;
      }
      _v1Program = bundle.v1Program;
      final v2Program = bundle.v2Program;

      final config = MorphRuntimeConfig.current;
      maybeLogRuntimeDeprecations(config);
      if (config.enableV2ShadowBindWhenV1 && v2Program != null) {
        _v2ShadowShader = v2Program.fragmentShader();
      }
      _v2RenderShader = config.useV2CrossRouteRender && v2Program != null
          ? v2Program.fragmentShader()
          : null;
      _program = v2Program ?? _v1Program;
      return _program;
    } catch (_) {
      return null;
    }
  }

  void _setState(CrossRouteMorphState next) {
    if (_state == next) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _setState(CrossRouteMorphState.disposed);
    _ticker?.dispose();
    _ticker = null;
    _removeOverlay();
    _session.clear();
    super.dispose();
  }
}

class _CrossRouteMorphPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ui.FragmentShader? v1Shader;
  final ui.FragmentShader? v2ShadowShader;
  final ui.FragmentShader? v2RenderShader;
  final bool useV2Render;
  final MorphTransitionConfig transitionConfig;
  final MorphSnapshot source;
  final MorphSnapshot destination;
  final MorphShape sourceShape;
  final MorphShape targetShape;
  final double progress;
  final MorphDirection direction;
  static const double _paintBleedPx = 16.0;

  _CrossRouteMorphPainter({
    required this.shader,
    required this.v1Shader,
    required this.v2ShadowShader,
    required this.v2RenderShader,
    required this.useV2Render,
    required this.transitionConfig,
    required this.source,
    required this.destination,
    required this.sourceShape,
    required this.targetShape,
    required this.progress,
    required this.direction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shapedProgress = transitionConfig.transformProgress(progress);
    final metadata = MorphCoordinator.buildSinglePairMetadataV2(
      logicalViewport: size,
      sourceRect: source,
      targetRect: destination,
      progress: shapedProgress,
      morphStyle: transitionConfig.shaderStyleIndex,
      sourceShape: sourceShape,
      targetShape: targetShape,
      // RuntimeEffect fragment coordinates are logical-canvas space.
      usePhysicalResolution: false,
    );

    if (v2ShadowShader != null) {
      MorphCoordinator.setUniformsV2Packed(
        shader: v2ShadowShader!,
        metadata: metadata,
      );
      v2ShadowShader!.setImageSampler(0, source.image);
      v2ShadowShader!.setImageSampler(1, destination.image);
    }
    if (useV2Render && v2RenderShader != null) {
      MorphCoordinator.setUniformsV2Packed(
        shader: v2RenderShader!,
        metadata: metadata,
      );
      v2RenderShader!.setImageSampler(0, source.image);
      v2RenderShader!.setImageSampler(1, destination.image);
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
      sourceRect: source,
      targetRect: destination,
      time: shapedProgress * 6.28,
      progress: shapedProgress,
    );
    final paintRegion = _computePaintRegion(size);
    if (paintRegion.isEmpty) {
      return;
    }
    canvas.drawRect(paintRegion, Paint()..shader = fallbackShader);
  }

  Rect _computePaintRegion(Size viewportSize) {
    final union = source.rect.expandToInclude(destination.rect);
    final expanded = union.inflate(_paintBleedPx);
    final viewport = Offset.zero & viewportSize;
    return expanded.intersect(viewport);
  }

  @override
  bool shouldRepaint(covariant _CrossRouteMorphPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.source != source ||
        oldDelegate.destination != destination ||
        oldDelegate.sourceShape != sourceShape ||
        oldDelegate.targetShape != targetShape ||
        oldDelegate.direction != direction;
  }
}

class _CrossRouteVisualState extends ChangeNotifier {
  MorphSnapshot source;
  MorphSnapshot destination;
  MorphShape sourceShape;
  MorphShape targetShape;
  MorphDirection direction;
  double progress;

  _CrossRouteVisualState({
    required this.source,
    required this.destination,
    required this.sourceShape,
    required this.targetShape,
    required this.direction,
    required this.progress,
  });

  void setDestination(MorphSnapshot next, MorphShape shape) {
    destination = next;
    targetShape = shape;
    notifyListeners();
  }

  void setProgress(double next) {
    if (progress == next) return;
    progress = next;
    notifyListeners();
  }

  void setDirection(MorphDirection next) {
    if (direction == next) return;
    direction = next;
    notifyListeners();
  }
}
