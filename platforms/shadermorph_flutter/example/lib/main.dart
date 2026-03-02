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
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const MorphDemoPage()));
          },
          child: const Text('Open Morph Demo'),
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
