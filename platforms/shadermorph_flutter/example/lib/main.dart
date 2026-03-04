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

class _MorphDemoPageState extends State<MorphDemoPage> {
  Widget _buildMorphCard({bool includeShadow = true}) {
    return Container(
      width: 250,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.blueAccent,
        borderRadius: BorderRadius.circular(20),
        boxShadow: includeShadow
            ? const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ]
            : null,
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

  Widget _buildMorphCard_2({bool includeShadow = true}) {
    return Container(
      width: 200,
      height: 100,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 68, 140),
        borderRadius: BorderRadius.circular(20),
        boxShadow: includeShadow
            ? const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ]
            : null,
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('ShaderMorph Demo'),
      ),
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: ShaderMorph(
        duration: const Duration(milliseconds: 600),
        backPopMode: BackPopMode.reverseThenPop,
        shadowCapturePolicy: MorphShadowCapturePolicy.exclude,
        triggerMode: ShaderMorphTriggerMode.onBuildForward,
        transitionConfig: const MorphTransitionConfig(
          interpolation: MorphInterpolation.easeInOut,
          shaderStyle: MorphShaderStyle.soft,
        ),
        destination: _buildMorphCard_2(includeShadow: true),
        destinationCapture: _buildMorphCard_2(includeShadow: false),
        source: _buildMorphCard(includeShadow: true),
        sourceCapture: _buildMorphCard(includeShadow: false),
        childBuilder: (context, morphChild) {
          final handle = ShaderMorphHandle.of(context);
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                morphChild,
                const SizedBox(height: 24),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: handle.forward,
                      child: const Text('Forward'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: handle.reverse,
                      child: const Text('Reverse'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
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

  Widget _buildMorphCard({bool includeShadow = true}) {
    return Container(
      width: 250,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.indigo,
        borderRadius: BorderRadius.circular(20),
        boxShadow: includeShadow
            ? const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ]
            : null,
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
    await ShaderMorph.push(
      context: context,
      tagId: _tagId,
      page: const CrossRouteDestinationPage(tagId: _tagId),
      shadowCapturePolicy: MorphShadowCapturePolicy.exclude,
      suppressTransition: true,
      transitionConfig: const MorphTransitionConfig(
        interpolation: MorphInterpolation.smoothStep,
        shaderStyle: MorphShaderStyle.soft,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cross-Route Source')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMorph.tag(
              id: _tagId,
              shadowCapturePolicy: MorphShadowCapturePolicy.exclude,
              captureChild: _buildMorphCard(includeShadow: false),
              child: _buildMorphCard(includeShadow: true),
            ),
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
  final String tagId;

  const CrossRouteDestinationPage({super.key, required this.tagId});

  Widget _buildMorphCard_3({bool includeShadow = true}) {
    return Container(
      width: 200,
      height: 120,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 9, 161, 112),
        borderRadius: BorderRadius.circular(20),
        boxShadow: includeShadow
            ? const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ]
            : null,
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
    await ShaderMorph.reverseAndPop(context, tagId: tagId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            ShaderMorph.tag(
              id: tagId,
              shadowCapturePolicy: MorphShadowCapturePolicy.exclude,
              captureChild: _buildMorphCard_3(includeShadow: false),
              child: _buildMorphCard_3(includeShadow: true),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _reverseThenPop(context),
              child: const Text('Reverse + Pop'),
            ),
          ],
        ),
      ),
    );
  }
}
