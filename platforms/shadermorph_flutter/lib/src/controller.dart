import 'dart:async';
import 'package:flutter/foundation.dart';

enum MorphDirection { forward, reverse }

enum MorphPlaybackState {
  idleSource,
  animatingForward,
  idleDestination,
  animatingReverse,
  disposed,
}

abstract class ShaderMorphPlaybackDelegate {
  Future<bool> play({required MorphDirection direction});
}

class ShaderMorphController extends ChangeNotifier {
  ShaderMorphPlaybackDelegate? _delegate;
  MorphPlaybackState _state = MorphPlaybackState.idleSource;

  MorphPlaybackState get state => _state;
  bool get isAnimating =>
      _state == MorphPlaybackState.animatingForward ||
      _state == MorphPlaybackState.animatingReverse;
  bool get isReady =>
      _state != MorphPlaybackState.disposed && _delegate != null;

  Future<bool> forward() => play(direction: MorphDirection.forward);

  Future<bool> reverse() => play(direction: MorphDirection.reverse);

  Future<bool> play({required MorphDirection direction}) {
    final delegate = _delegate;
    if (delegate == null || _state == MorphPlaybackState.disposed) {
      return Future.value(false);
    }
    return delegate.play(direction: direction);
  }

  Future<bool> waitForState(
    MorphPlaybackState target, {
    Duration? timeout,
  }) async {
    if (_state == target) return true;

    final completer = Completer<bool>();
    Timer? timer;
    late VoidCallback listener;

    listener = () {
      if (_state == target && !completer.isCompleted) {
        timer?.cancel();
        removeListener(listener);
        completer.complete(true);
      }
    };

    addListener(listener);

    if (timeout != null) {
      timer = Timer(timeout, () {
        if (!completer.isCompleted) {
          removeListener(listener);
          completer.complete(false);
        }
      });
    }

    return completer.future;
  }

  void attach(ShaderMorphPlaybackDelegate delegate) {
    _delegate = delegate;
    if (_state == MorphPlaybackState.disposed) {
      _state = MorphPlaybackState.idleSource;
      notifyListeners();
    }
  }

  void detach(ShaderMorphPlaybackDelegate delegate) {
    if (identical(_delegate, delegate)) {
      _delegate = null;
    }
  }

  @override
  void dispose() {
    _delegate = null;
    _setState(MorphPlaybackState.disposed);
    super.dispose();
  }

  @visibleForTesting
  void debugSetState(MorphPlaybackState state) {
    _setState(state);
  }

  void setStateFromHost(MorphPlaybackState state) {
    _setState(state);
  }

  void resetToSource() {
    if (_state == MorphPlaybackState.disposed) return;
    _setState(MorphPlaybackState.idleSource);
  }

  void _setState(MorphPlaybackState state) {
    if (_state == state) return;
    _state = state;
    notifyListeners();
  }
}
