import 'package:flutter/material.dart';

import 'controller.dart';

enum BackPopMode { reverseThenPop, immediatePopReset }

class ShaderMorphPopHandler extends StatelessWidget {
  final ShaderMorphController controller;
  final Widget child;
  final Duration reverseTimeout;
  final bool fallbackPopOnFailure;
  final BackPopMode backPopMode;

  const ShaderMorphPopHandler({
    super.key,
    required this.controller,
    required this.child,
    this.reverseTimeout = const Duration(milliseconds: 1200),
    this.fallbackPopOnFailure = true,
    this.backPopMode = BackPopMode.reverseThenPop,
  });

  @override
  Widget build(BuildContext context) {
    return _ShaderMorphPopScope(
      controller: controller,
      reverseTimeout: reverseTimeout,
      fallbackPopOnFailure: fallbackPopOnFailure,
      backPopMode: backPopMode,
      child: child,
    );
  }
}

class _ShaderMorphPopScope extends StatefulWidget {
  final ShaderMorphController controller;
  final Duration reverseTimeout;
  final bool fallbackPopOnFailure;
  final BackPopMode backPopMode;
  final Widget child;

  const _ShaderMorphPopScope({
    required this.controller,
    required this.reverseTimeout,
    required this.fallbackPopOnFailure,
    required this.backPopMode,
    required this.child,
  });

  @override
  State<_ShaderMorphPopScope> createState() => _ShaderMorphPopScopeState();
}

class _ShaderMorphPopScopeState extends State<_ShaderMorphPopScope> {
  bool _isHandlingPop = false;
  bool _allowNextPop = false;

  Future<void> _popWithBypass(NavigatorState navigator, Object? result) async {
    if (!mounted || !navigator.mounted) return;
    setState(() {
      _allowNextPop = true;
    });
    try {
      if (navigator.canPop()) {
        navigator.pop(result);
        return;
      }
      await navigator.maybePop(result);
    } finally {
      if (!mounted) return;
      setState(() {
        _allowNextPop = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowNextPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _isHandlingPop) return;
        final navigator = Navigator.of(context);

        _isHandlingPop = true;
        try {
          if (widget.backPopMode == BackPopMode.immediatePopReset) {
            widget.controller.resetToSource();
            await _popWithBypass(navigator, result);
            return;
          }

          if (widget.controller.state != MorphPlaybackState.idleDestination) {
            await _popWithBypass(navigator, result);
            return;
          }

          final started = await widget.controller.reverse();
          if (!started) {
            if (widget.fallbackPopOnFailure) {
              await _popWithBypass(navigator, result);
            }
            return;
          }

          final completed = await widget.controller.waitForState(
            MorphPlaybackState.idleSource,
            timeout: widget.reverseTimeout,
          );
          if (completed || widget.fallbackPopOnFailure) {
            await _popWithBypass(navigator, result);
          }
        } finally {
          _isHandlingPop = false;
        }
      },
      child: widget.child,
    );
  }
}

Route<void> buildMorphRoute({
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

class ShaderMorphRouteBridge extends RouteAware {
  final ShaderMorphController controller;
  final bool forwardOnPush;
  final bool reverseOnPopNext;

  ShaderMorphRouteBridge({
    required this.controller,
    this.forwardOnPush = true,
    this.reverseOnPopNext = false,
  });

  @override
  void didPush() {
    if (forwardOnPush) {
      controller.forward();
    }
  }

  @override
  void didPopNext() {
    if (reverseOnPopNext) {
      controller.reverse();
    }
  }
}
