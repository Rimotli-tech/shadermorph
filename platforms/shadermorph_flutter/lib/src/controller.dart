import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

class ShaderMorphController extends ChangeNotifier {
  ShaderMorphController({
    required TickerProvider vsync,
    Duration duration = const Duration(milliseconds: 650),
  }) : _animation = AnimationController(vsync: vsync, duration: duration) {
    _animation.addListener(notifyListeners);
  }

  final AnimationController _animation;

  double get progress => _animation.value;
  bool get isAnimating => _animation.isAnimating;
  Duration get duration => _animation.duration ?? Duration.zero;

  set duration(Duration value) {
    _animation.duration = value;
  }

  Future<void> forward({double from = 0.0}) {
    return _animation.forward(from: from);
  }

  Future<void> reverse({double from = 1.0}) {
    return _animation.reverse(from: from);
  }

  @override
  void dispose() {
    _animation.removeListener(notifyListeners);
    _animation.dispose();
    super.dispose();
  }
}
