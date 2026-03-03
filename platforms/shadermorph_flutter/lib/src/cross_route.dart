import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'coordinator.dart';
import 'controller.dart';
import 'models.dart';
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
    return ValueListenableBuilder<Set<String>>(
      valueListenable: MorphTagRegistry.instance.hiddenTags,
      builder: (context, hiddenTags, _) {
        final hidden = hiddenTags.contains(widget.id);
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

  final Map<String, GlobalKey> _tags = <String, GlobalKey>{};
  final ValueNotifier<Set<String>> hiddenTags = ValueNotifier<Set<String>>(
    <String>{},
  );

  void register(String id, GlobalKey key) {
    _tags[id] = key;
  }

  void unregister(String id, GlobalKey key) {
    final current = _tags[id];
    if (identical(current, key)) {
      _tags.remove(id);
      setHidden(id, false);
    }
  }

  GlobalKey? keyFor(String id) => _tags[id];

  Future<MorphSnapshot?> captureById(String id) async {
    final key = _tags[id];
    if (key == null) return null;
    try {
      return await MorphTracker.capture(key);
    } catch (_) {
      return null;
    }
  }

  void setHidden(String id, bool hidden) {
    final updated = Set<String>.from(hiddenTags.value);
    if (hidden) {
      updated.add(id);
    } else {
      updated.remove(id);
    }
    if (!setEquals(updated, hiddenTags.value)) {
      hiddenTags.value = updated;
    }
  }

  @visibleForTesting
  void clearForTesting() {
    _tags.clear();
    hiddenTags.value = <String>{};
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

    final sourceSnapshot = await _registry.captureById(tagId);
    if (sourceSnapshot == null) return false;
    if (!context.mounted) return false;
    final navigator = Navigator.of(context);
    final overlayState = Overlay.of(context, rootOverlay: true);
    final program = await _loadProgram();
    if (program == null || !overlayState.mounted) return false;

    _session.setSource(id: tagId, snapshot: sourceSnapshot);
    final expectedToken = _session.token;
    _registry.setHidden(tagId, true);
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

    final destinationSnapshot = await _waitForSnapshotById(
      tagId,
      timeout: const Duration(seconds: 3),
    );
    if (destinationSnapshot == null || _session.token != expectedToken) {
      _registry.setHidden(tagId, false);
      _removeOverlay();
      _setState(CrossRouteMorphState.idle);
      return false;
    }

    _setState(CrossRouteMorphState.animatingForward);
    _visualState?.setDestination(destinationSnapshot);

    final completed = await _animateOverlay(
      direction: MorphDirection.forward,
      expectedToken: expectedToken,
    );
    _removeOverlay();
    _registry.setHidden(tagId, false);
    _setState(
      completed
          ? CrossRouteMorphState.atDestination
          : CrossRouteMorphState.idle,
    );
    return completed;
  }

  Future<bool> playForward({
    required BuildContext context,
    required String tagId,
  }) async {
    if (_state == CrossRouteMorphState.disposed || isAnimating) return false;
    if (!_session.hasSessionFor(tagId)) return false;
    final source = _session.source;
    if (source == null) return false;

    final destination = await _registry.captureById(tagId);
    if (destination == null) return false;
    if (!context.mounted) return false;
    final overlayState = Overlay.of(context, rootOverlay: true);

    _setState(CrossRouteMorphState.animatingForward);
    _registry.setHidden(tagId, true);

    final ok = await _runOverlayAnimation(
      overlayState: overlayState,
      source: source,
      destination: destination,
      direction: MorphDirection.forward,
      expectedToken: _session.token,
    );
    _registry.setHidden(tagId, false);
    _setState(
      ok ? CrossRouteMorphState.atDestination : CrossRouteMorphState.idle,
    );
    return ok;
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
    final currentDestination = await _registry.captureById(tagId);
    if (currentDestination == null) return false;
    if (!context.mounted) return false;
    final overlayState = Overlay.of(context, rootOverlay: true);

    _setState(CrossRouteMorphState.animatingReverse);
    _registry.setHidden(tagId, true);

    final ok = await _runOverlayAnimation(
      overlayState: overlayState,
      source: currentDestination,
      destination: source,
      direction: MorphDirection.reverse,
      expectedToken: _session.token,
    );
    _registry.setHidden(tagId, false);
    _setState(
      ok
          ? CrossRouteMorphState.capturedSource
          : CrossRouteMorphState.atDestination,
    );
    return ok;
  }

  Future<bool> playReverseBeforePop({
    required BuildContext context,
    required String tagId,
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    final navigator = Navigator.of(context);
    final started = await playReverse(context: context, tagId: tagId);
    if (!started) return false;

    final completed = await _waitForState(
      CrossRouteMorphState.capturedSource,
      timeout: timeout,
    );
    if (completed && navigator.mounted) {
      navigator.pop();
    }
    return completed;
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

  Future<MorphSnapshot?> _waitForSnapshotById(
    String tagId, {
    required Duration timeout,
  }) async {
    final sw = Stopwatch()..start();
    while (sw.elapsed < timeout && _state != CrossRouteMorphState.disposed) {
      await SchedulerBinding.instance.endOfFrame;
      final snapshot = await _registry.captureById(tagId);
      if (snapshot != null) {
        return snapshot;
      }
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    return null;
  }

  Future<ui.FragmentProgram?> _loadProgram() async {
    if (_program != null) return _program;
    try {
      _program = await ui.FragmentProgram.fromAsset(
        'packages/shadermorph_flutter/shaders/shader_engine.frag',
      );
      return _program;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _waitForState(
    CrossRouteMorphState target, {
    required Duration timeout,
  }) async {
    if (_state == target) return true;
    final completer = Completer<bool>();
    late VoidCallback listener;
    Timer? timer;

    listener = () {
      if (_state == target && !completer.isCompleted) {
        timer?.cancel();
        removeListener(listener);
        completer.complete(true);
      }
    };

    addListener(listener);
    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        removeListener(listener);
        completer.complete(false);
      }
    });
    return completer.future;
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
          final started = await widget.controller.playReverse(
            context: context,
            tagId: widget.tagId,
          );
          if (started) {
            final completed = await widget.controller._waitForState(
              CrossRouteMorphState.capturedSource,
              timeout: widget.reverseTimeout,
            );
            if (completed && navigator.mounted) {
              navigator.maybePop(result);
              return;
            }
          }
          if (widget.fallbackPopOnFailure && navigator.mounted) {
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
  final MorphSnapshot source;
  final MorphSnapshot destination;
  final double progress;
  final MorphDirection direction;

  _CrossRouteMorphPainter({
    required this.shader,
    required this.source,
    required this.destination,
    required this.progress,
    required this.direction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final effectiveProgress = direction == MorphDirection.forward
        ? progress
        : (1.0 - progress);
    MorphCoordinator.setUniforms(
      shader: shader,
      viewport: size,
      sourceRect: source,
      targetRect: destination,
      time: progress * 6.28,
      progress: effectiveProgress,
    );
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
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
