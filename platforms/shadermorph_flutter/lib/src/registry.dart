import 'package:flutter/widgets.dart';

import 'tracker.dart';

class ShaderMorphScope extends InheritedWidget {
  const ShaderMorphScope({
    super.key,
    required this.screenId,
    required super.child,
  });

  final String screenId;

  static ShaderMorphScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShaderMorphScope>();
  }

  @override
  bool updateShouldNotify(covariant ShaderMorphScope oldWidget) {
    return oldWidget.screenId != screenId;
  }
}

class ShaderMorphTag extends StatefulWidget {
  const ShaderMorphTag({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  State<ShaderMorphTag> createState() => ShaderMorphTagState();
}

class ShaderMorphTagState extends State<ShaderMorphTag> {
  final GlobalKey _renderKey = GlobalKey();
  String? _registeredScreenId;

  RenderBox? get renderBox {
    final renderObject = _renderKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox &&
        renderObject.hasSize &&
        renderObject.attached) {
      return renderObject;
    }
    return null;
  }

  Rect? get logicalRect {
    final context = _renderKey.currentContext;
    if (context == null) {
      return null;
    }
    return GeometryTracker.extractLogicalRect(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRegistration();
  }

  @override
  void didUpdateWidget(covariant ShaderMorphTag oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _syncRegistration(force: true);
    }
  }

  @override
  void dispose() {
    _unregister();
    super.dispose();
  }

  void _syncRegistration({bool force = false}) {
    final scope = ShaderMorphScope.maybeOf(context);
    final nextScreenId = scope?.screenId;
    if (!force && _registeredScreenId == nextScreenId) {
      return;
    }
    _unregister();
    if (nextScreenId != null) {
      ShaderMorphTagRegistry.instance.register(nextScreenId, widget.id, this);
      _registeredScreenId = nextScreenId;
    }
  }

  void _unregister() {
    final screenId = _registeredScreenId;
    if (screenId != null) {
      ShaderMorphTagRegistry.instance.unregister(screenId, widget.id, this);
      _registeredScreenId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _renderKey, child: widget.child);
  }
}

class ShaderMorphTagRegistry {
  ShaderMorphTagRegistry._();

  static final ShaderMorphTagRegistry instance = ShaderMorphTagRegistry._();

  final Map<String, Map<String, ShaderMorphTagState>> _tagsByScreen =
      <String, Map<String, ShaderMorphTagState>>{};

  void register(String screenId, String tagId, ShaderMorphTagState state) {
    final screenTags = _tagsByScreen.putIfAbsent(
      screenId,
      () => <String, ShaderMorphTagState>{},
    );
    screenTags[tagId] = state;
  }

  void unregister(String screenId, String tagId, ShaderMorphTagState state) {
    final screenTags = _tagsByScreen[screenId];
    if (screenTags == null) {
      return;
    }
    final current = screenTags[tagId];
    if (identical(current, state)) {
      screenTags.remove(tagId);
    }
    if (screenTags.isEmpty) {
      _tagsByScreen.remove(screenId);
    }
  }

  Map<String, ShaderMorphTagState> getTagsForScreen(String screenId) {
    return Map<String, ShaderMorphTagState>.from(
      _tagsByScreen[screenId] ?? const {},
    );
  }
}
