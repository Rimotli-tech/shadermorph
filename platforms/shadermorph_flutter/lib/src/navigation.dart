import 'package:flutter/material.dart';

import 'controller.dart';

class ShaderMorphPopHandler extends StatelessWidget {
  final ShaderMorphController controller;
  final Widget child;
  final Duration reverseTimeout;
  final bool fallbackPopOnFailure;

  const ShaderMorphPopHandler({
    super.key,
    required this.controller,
    required this.child,
    this.reverseTimeout = const Duration(milliseconds: 1200),
    this.fallbackPopOnFailure = true,
  });

  @override
  Widget build(BuildContext context) {
    return _ShaderMorphPopScope(
      controller: controller,
      reverseTimeout: reverseTimeout,
      fallbackPopOnFailure: fallbackPopOnFailure,
      child: child,
    );
  }
}

class _ShaderMorphPopScope extends StatefulWidget {
  final ShaderMorphController controller;
  final Duration reverseTimeout;
  final bool fallbackPopOnFailure;
  final Widget child;

  const _ShaderMorphPopScope({
    required this.controller,
    required this.reverseTimeout,
    required this.fallbackPopOnFailure,
    required this.child,
  });

  @override
  State<_ShaderMorphPopScope> createState() => _ShaderMorphPopScopeState();
}

class _ShaderMorphPopScopeState extends State<_ShaderMorphPopScope> {
  bool _isHandlingPop = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.controller.state != MorphPlaybackState.idleDestination,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _isHandlingPop) return;
        final navigator = Navigator.of(context);

        _isHandlingPop = true;
        try {
          if (widget.controller.state != MorphPlaybackState.idleDestination) {
            if (navigator.mounted) {
              navigator.maybePop(result);
            }
            return;
          }

          final started = await widget.controller.reverse();
          if (!started) {
            if (widget.fallbackPopOnFailure && navigator.mounted) {
              navigator.maybePop(result);
            }
            return;
          }

          final completed = await widget.controller.waitForState(
            MorphPlaybackState.idleSource,
            timeout: widget.reverseTimeout,
          );
          if ((completed || widget.fallbackPopOnFailure) && navigator.mounted) {
            navigator.maybePop(result);
          }
        } finally {
          _isHandlingPop = false;
        }
      },
      child: widget.child,
    );
  }
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
