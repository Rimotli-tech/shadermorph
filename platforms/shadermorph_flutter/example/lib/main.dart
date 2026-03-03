import 'package:flutter/material.dart';
import 'package:shadermorph_flutter/shadermorph_flutter.dart';

final RouteObserver<PageRoute<dynamic>> morphRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

void main() {
  runApp(const ExampleRoot());
}

class ExampleRoot extends StatelessWidget {
  const ExampleRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorObservers: [morphRouteObserver],
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MorphDemoPage()),
                );
              },
              child: const Text('Open Single-Page Morph Demo'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CrossRouteSourcePage(),
                  ),
                );
              },
              child: const Text('Open Cross-Route Morph Demo'),
            ),
          ],
        ),
      ),
    );
  }
}

class MorphDemoPage extends StatefulWidget {
  const MorphDemoPage({super.key});

  @override
  State<MorphDemoPage> createState() => _MorphDemoPageState();
}

class _MorphDemoPageState extends State<MorphDemoPage> with RouteAware {
  final ShaderMorphController _controller = ShaderMorphController();
  ShaderMorphRouteBridge? _routeBridge;
  bool _isRouteBridgeSubscribed = false;

  Widget _buildMorphCard() {
    return Container(
      width: 250,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.blueAccent,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          "Source",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMorphCard_2() {
    return Container(
      width: 200,
      height: 100,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 68, 140),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          "Destination",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      _routeBridge ??= ShaderMorphRouteBridge(
        controller: _controller,
        forwardOnPush: true,
      );
      if (!_isRouteBridgeSubscribed) {
        morphRouteObserver.subscribe(_routeBridge!, route);
        _isRouteBridgeSubscribed = true;
      }
    }
  }

  Future<void> _reverseThenPop() async {
    final navigator = Navigator.of(context);
    final started = await _controller.reverse();
    if (!started) {
      if (mounted) navigator.pop();
      return;
    }

    await _controller.waitForState(
      MorphPlaybackState.idleSource,
      timeout: const Duration(milliseconds: 1500),
    );
    if (mounted) navigator.pop();
  }

  @override
  void dispose() {
    if (_routeBridge != null) {
      morphRouteObserver.unsubscribe(_routeBridge!);
      _isRouteBridgeSubscribed = false;
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShaderMorphPopHandler(
      controller: _controller,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _reverseThenPop,
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('ShaderMorph Demo'),
        ),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMorph(
                controller: _controller,
                duration: const Duration(milliseconds: 3000),
                destination: _buildMorphCard_2(),
                source: _buildMorphCard(),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: _controller.forward,
                    child: const Text('Forward'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _controller.reverse,
                    child: const Text('Reverse'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CrossRouteSourcePage extends StatefulWidget {
  const CrossRouteSourcePage({super.key});

  @override
  State<CrossRouteSourcePage> createState() => _CrossRouteSourcePageState();
}

class _CrossRouteSourcePageState extends State<CrossRouteSourcePage> {
  static const String _tagId = 'cross_route_card';
  final CrossRouteMorphController _controller = CrossRouteMorphController(
    duration: const Duration(milliseconds: 1800),
  );

  Widget _buildMorphCard() {
    return Container(
      width: 250,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.indigo,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'Cross-Route Source',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<void> _goToDestination() async {
    await _controller.startToRoute(
      context: context,
      tagId: _tagId,
      route: MaterialPageRoute<void>(
        builder: (_) =>
            CrossRouteDestinationPage(controller: _controller, tagId: _tagId),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cross-Route Source')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MorphTag(id: _tagId, child: _buildMorphCard()),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _goToDestination,
              child: const Text('Go To Destination (Auto Morph)'),
            ),
          ],
        ),
      ),
    );
  }
}

class CrossRouteDestinationPage extends StatelessWidget {
  final CrossRouteMorphController controller;
  final String tagId;

  const CrossRouteDestinationPage({
    super.key,
    required this.controller,
    required this.tagId,
  });

  Widget _buildMorphCard_3() {
    return Container(
      width: 200,
      height: 120,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 9, 161, 112),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'Destination 3',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<void> _reverseThenPop(BuildContext context) async {
    final ok = await controller.playReverseDuringPop(
      context: context,
      tagId: tagId,
    );
    if (!ok && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CrossRouteMorphPopHandler(
      controller: controller,
      tagId: tagId,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cross-Route Destination'),
          leading: IconButton(
            onPressed: () => _reverseThenPop(context),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MorphTag(id: tagId, child: _buildMorphCard_3()),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _reverseThenPop(context),
                child: const Text('Reverse + Pop'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
