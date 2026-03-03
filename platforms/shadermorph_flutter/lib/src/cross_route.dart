import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'coordinator.dart';
import 'controller.dart';
import 'models.dart';
import 'runtime_config.dart';
import 'tracker.dart';

enum CrossRouteMorphState {
  idle,
  capturedSource,
  animatingForward,
  atDestination,
  animatingReverse,
  disposed,
}

class MorphTag extends StatefulWidget {
  final String id;
  final Widget child;

  const MorphTag({super.key, required this.id, required this.child});

  @override
  State<MorphTag> createState() => _MorphTagState();
}

class _MorphTagState extends State<MorphTag> {
  final GlobalKey _paintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    MorphTagRegistry.instance.register(widget.id, _paintKey);
  }

  @override
  void didUpdateWidget(covariant MorphTag oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      MorphTagRegistry.instance.unregister(oldWidget.id, _paintKey);
      MorphTagRegistry.instance.register(widget.id, _paintKey);
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
        final hidden = hiddenTags.contains(_paintKey);
        return Opacity(
          opacity: hidden ? 0.0 : 1.0,
          child: RepaintBoundary(key: _paintKey, child: widget.child),
        );
      },
    );
  }
}

class MorphTagRegistry {
  MorphTagRegistry._();

  static final MorphTagRegistry instance = MorphTagRegistry._();

  final Map<String, List<GlobalKey>> _tags = <String, List<GlobalKey>>{};
  final ValueNotifier<Set<GlobalKey>> hiddenTags = ValueNotifier<Set<GlobalKey>>(
    <GlobalKey>{},
  );

  void register(String id, GlobalKey key) {
    final keys = _tags.putIfAbsent(id, () => <GlobalKey>[]);
    if (!keys.contains(key)) {
      keys.add(key);
    }
  }

  void unregister(String id, GlobalKey key) {
    final keys = _tags[id];
    if (keys == null) return;
    keys.remove(key);
    if (keys.isEmpty) {
      _tags.remove(id);
    }
  }

  GlobalKey? keyFor(String id) => _latestMountedKey(id);

  Future<MorphSnapshot?> captureById(String id) async {
    final key = keyFor(id);
    if (key == null) return null;
    return captureByKey(key);
  }

  Future<MorphSnapshot?> captureByKey(GlobalKey key) async {
    try {
      return await MorphTracker.capture(key);
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

  @visibleForTesting
  void clearForTesting() {
    _tags.clear();
    hiddenTags.value = <GlobalKey>{};
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
  MorphSnapshot? source;
  int _token = 0;

  int nextToken() {
    _token += 1;
    return _token;
  }

  int get token => _token;

  bool hasSessionFor(String id) => source != null && tagId == id;

  void setSource({required String id, required MorphSnapshot snapshot}) {
    tagId = id;
    source = snapshot;
    nextToken();
  }

  void clear() {
    tagId = null;
    source = null;
    nextToken();
  }
}

class CrossRouteMorphController extends ChangeNotifier {
  final Duration duration;
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

  CrossRouteMorphController({
    this.duration = const Duration(milliseconds: 800),
    MorphTagRegistry? registry,
    CrossRouteMorphSessionStore? session,
  }) : _registry = registry ?? MorphTagRegistry.instance,
       _session = session ?? CrossRouteMorphSessionStore();

  CrossRouteMorphState get state => _state;

  bool get isAnimating =>
      _state == CrossRouteMorphState.animatingForward ||
      _state == CrossRouteMorphState.animatingReverse;

  bool canReverse(String tagId) =>
      _state == CrossRouteMorphState.atDestination &&
      _session.hasSessionFor(tagId);

  Future<bool> startToRoute({
    required BuildContext context,
    required String tagId,
    required Route<void> route,
  }) async {
    if (_state == CrossRouteMorphState.disposed || isAnimating) return false;

    final sourceKey = _registry.keyFor(tagId);
    if (sourceKey == null) return false;
    final sourceSnapshot = await _registry.captureByKey(sourceKey);
    if (sourceSnapshot == null) return false;
    if (!context.mounted) return false;
    final navigator = Navigator.of(context);
    final overlayState = Overlay.of(context, rootOverlay: true);
    final program = await _loadProgram();
    if (program == null || !overlayState.mounted) return false;

    _session.setSource(id: tagId, snapshot: sourceSnapshot);
    final expectedToken = _session.token;
    GlobalKey? destinationKey;
    try {
      // Hide source endpoint before route push to avoid double-draw on source page.
      _registry.setHiddenForKey(sourceKey, hidden: true);
      _setState(CrossRouteMorphState.capturedSource);

      _showOverlay(
        overlayState: overlayState,
        program: program,
        source: sourceSnapshot,
        destination: sourceSnapshot,
        direction: MorphDirection.forward,
        progress: 0.0,
      );

      unawaited(navigator.push(route));
      destinationKey = await _waitForTargetKey(
        tagId,
        excludedKey: sourceKey,
        timeout: const Duration(seconds: 3),
      );
      if (destinationKey == null || _session.token != expectedToken) {
        _setState(CrossRouteMorphState.idle);
        return false;
      }
      final destinationSnapshot = await _waitForStableSnapshotByKey(
        destinationKey,
        timeout: const Duration(seconds: 3),
      );
      if (destinationSnapshot == null || _session.token != expectedToken) {
        _setState(CrossRouteMorphState.idle);
        return false;
      }

      _registry.setHiddenForKey(destinationKey, hidden: true);
      _setState(CrossRouteMorphState.animatingForward);
      _visualState?.setDestination(destinationSnapshot);

      final completed = await _animateOverlay(
        direction: MorphDirection.forward,
        expectedToken: expectedToken,
      );
      _setState(
        completed
            ? CrossRouteMorphState.atDestination
            : CrossRouteMorphState.idle,
      );
      return completed;
    } finally {
      _removeOverlay();
      _registry.setHiddenForKey(sourceKey, hidden: false);
      if (destinationKey != null) {
        _registry.setHiddenForKey(destinationKey, hidden: false);
      }
    }
  }

  Future<bool> playForward({
    required BuildContext context,
    required String tagId,
  }) async {
    if (_state == CrossRouteMorphState.disposed || isAnimating) return false;
    if (!_session.hasSessionFor(tagId)) return false;
    final source = _session.source;
    if (source == null) return false;
    final destinationKey = _registry.keyFor(tagId);
    if (destinationKey == null) return false;

    final destination = await _registry.captureByKey(destinationKey);
    if (destination == null) return false;
    if (!context.mounted) return false;
    final overlayState = Overlay.of(context, rootOverlay: true);

    _setState(CrossRouteMorphState.animatingForward);
    _registry.setHiddenForKey(destinationKey, hidden: true);
    try {
      final ok = await _runOverlayAnimation(
        overlayState: overlayState,
        source: source,
        destination: destination,
        direction: MorphDirection.forward,
        expectedToken: _session.token,
      );
      _setState(
        ok ? CrossRouteMorphState.atDestination : CrossRouteMorphState.idle,
      );
      return ok;
    } finally {
      _registry.setHiddenForKey(destinationKey, hidden: false);
    }
  }

  Future<bool> playReverse({
    required BuildContext context,
    required String tagId,
  }) async {
    if (_state == CrossRouteMorphState.disposed || isAnimating) return false;
    if (!_session.hasSessionFor(tagId)) return false;
    if (_state != CrossRouteMorphState.atDestination) return false;

    final source = _session.source;
    if (source == null) return false;
    final destinationKey = _registry.keyFor(tagId);
    if (destinationKey == null) return false;
    final currentDestination = await _registry.captureByKey(destinationKey);
    if (currentDestination == null) return false;
    if (!context.mounted) return false;
    final overlayState = Overlay.of(context, rootOverlay: true);

    _setState(CrossRouteMorphState.animatingReverse);
    _registry.setHiddenForKey(destinationKey, hidden: true);
    try {
      final ok = await _runOverlayAnimation(
        overlayState: overlayState,
        source: currentDestination,
        destination: source,
        direction: MorphDirection.reverse,
        expectedToken: _session.token,
      );
      _setState(
        ok
            ? CrossRouteMorphState.capturedSource
            : CrossRouteMorphState.atDestination,
      );
      return ok;
    } finally {
      _registry.setHiddenForKey(destinationKey, hidden: false);
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
    final source = _session.source;
    if (source == null) return false;

    final destinationKey = _registry.keyFor(tagId);
    if (destinationKey == null) return false;
    final destinationSnapshot = await _registry.captureByKey(destinationKey);
    if (destinationSnapshot == null) return false;
    if (!context.mounted) return false;
    final overlayState = Overlay.of(context, rootOverlay: true);
    final program = await _loadProgram();
    if (program == null || !overlayState.mounted) return false;
    if (!context.mounted) return false;
    final navigator = Navigator.of(context);
    final sourceKey = _registry.keyForExcluding(tagId, destinationKey);
    final expectedToken = _session.token;

    _registry.setHiddenForKey(destinationKey, hidden: true);
    if (sourceKey != null) {
      _registry.setHiddenForKey(sourceKey, hidden: true);
    }
    _setState(CrossRouteMorphState.animatingReverse);

    bool completed = false;
    try {
      _showOverlay(
        overlayState: overlayState,
        program: program,
        source: destinationSnapshot,
        destination: source,
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
      _registry.setHiddenForKey(destinationKey, hidden: false);
      if (sourceKey != null) {
        _registry.setHiddenForKey(sourceKey, hidden: false);
      }
      _setState(
        completed
            ? CrossRouteMorphState.capturedSource
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
    required MorphDirection direction,
    required int expectedToken,
  }) async {
    final program = await _loadProgram();
    if (program == null) return false;
    if (overlayState.mounted == false) return false;

    _showOverlay(
      overlayState: overlayState,
      program: program,
      source: source,
      destination: destination,
      direction: direction,
      progress: 0.0,
    );
    final completed = await _animateOverlay(
      direction: direction,
      expectedToken: expectedToken,
    );
    _removeOverlay();
    return completed;
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
    required MorphDirection direction,
    required double progress,
  }) {
    _removeOverlay();
    _visualState = _CrossRouteVisualState(
      source: source,
      destination: destination,
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
                  source: state.source,
                  destination: state.destination,
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
    MorphSnapshot? latest;
    var stableFrames = 0;
    while (sw.elapsed < timeout && _state != CrossRouteMorphState.disposed) {
      await SchedulerBinding.instance.endOfFrame;
      final snapshot = await _registry.captureByKey(key);
      if (snapshot != null) {
        latest = snapshot;
        if (previous != null &&
            _isRectStable(
              previous.rect,
              snapshot.rect,
              epsilon: rectEpsilonPx,
            )) {
          stableFrames += 1;
        } else {
          stableFrames = 1;
        }
        previous = snapshot;
        if (stableFrames >= consecutiveStableFrames) {
          return latest;
        }
      } else {
        stableFrames = 0;
      }
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    return latest;
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
      _v1Program = await ui.FragmentProgram.fromAsset(
        'packages/shadermorph_flutter/shaders/shader_engine.frag',
      );
      ui.FragmentProgram? v2Program;
      try {
        v2Program = await ui.FragmentProgram.fromAsset(
          'packages/shadermorph_flutter/shaders/shader_engine_v2.frag',
        );
      } catch (_) {
        // Keep rendering available via V1 fallback if V2 cannot load.
      }

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

class CrossRouteMorphPopHandler extends StatefulWidget {
  final CrossRouteMorphController controller;
  final String tagId;
  final Widget child;
  final Duration reverseTimeout;
  final bool fallbackPopOnFailure;

  const CrossRouteMorphPopHandler({
    super.key,
    required this.controller,
    required this.tagId,
    required this.child,
    this.reverseTimeout = const Duration(milliseconds: 1500),
    this.fallbackPopOnFailure = true,
  });

  @override
  State<CrossRouteMorphPopHandler> createState() =>
      _CrossRouteMorphPopHandlerState();
}

class _CrossRouteMorphPopHandlerState extends State<CrossRouteMorphPopHandler> {
  bool _handling = false;

  @override
  Widget build(BuildContext context) {
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
            timeout: widget.reverseTimeout,
          );
          if (!started && widget.fallbackPopOnFailure && navigator.mounted) {
            navigator.maybePop(result);
          }
        } finally {
          _handling = false;
        }
      },
      child: widget.child,
    );
  }
}

class _CrossRouteMorphPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ui.FragmentShader? v1Shader;
  final ui.FragmentShader? v2ShadowShader;
  final ui.FragmentShader? v2RenderShader;
  final bool useV2Render;
  final MorphSnapshot source;
  final MorphSnapshot destination;
  final double progress;
  final MorphDirection direction;

  _CrossRouteMorphPainter({
    required this.shader,
    required this.v1Shader,
    required this.v2ShadowShader,
    required this.v2RenderShader,
    required this.useV2Render,
    required this.source,
    required this.destination,
    required this.progress,
    required this.direction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final metadata = MorphCoordinator.buildSinglePairMetadataV2(
      logicalViewport: size,
      sourceRect: source,
      targetRect: destination,
      progress: progress,
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
      canvas.drawRect(Offset.zero & size, Paint()..shader = v2RenderShader);
      return;
    }

    // Deprecated emergency fallback path. Remove after V2 stabilization window.
    final fallbackShader = v1Shader ?? shader;
    MorphCoordinator.setUniforms(
      shader: fallbackShader,
      viewport: size,
      sourceRect: source,
      targetRect: destination,
      time: progress * 6.28,
      progress: progress,
    );
    canvas.drawRect(Offset.zero & size, Paint()..shader = fallbackShader);
  }

  @override
  bool shouldRepaint(covariant _CrossRouteMorphPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.source != source ||
        oldDelegate.destination != destination ||
        oldDelegate.direction != direction;
  }
}

class _CrossRouteVisualState extends ChangeNotifier {
  MorphSnapshot source;
  MorphSnapshot destination;
  MorphDirection direction;
  double progress;

  _CrossRouteVisualState({
    required this.source,
    required this.destination,
    required this.direction,
    required this.progress,
  });

  void setDestination(MorphSnapshot next) {
    destination = next;
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
