import 'package:flutter/material.dart';
import 'package:shadermorph_flutter/shadermorph_flutter.dart';

void main() {
  runApp(const ExampleRoot());
}

class ExampleRoot extends StatelessWidget {
  const ExampleRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const MorphDemoPage(),
    );
  }
}

class MorphDemoPage extends StatelessWidget {
  const MorphDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ShaderMorphHost(
      duration: const Duration(milliseconds: 700),
      transitionConfig: const MorphTransitionConfig(
        interpolation: MorphInterpolation.easeInOut,
        shaderStyle: MorphShaderStyle.standard,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF111014),
        appBar: AppBar(
          backgroundColor: const Color(0xFF111014),
          foregroundColor: Colors.white,
          title: const Text('Single-Page Host + Tags'),
        ),
        body: const _PageContent(),
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  const _PageContent();

  static const String singlePageTagId = 'card42';
  static const String crossRouteTagId = 'route_card42';

  @override
  Widget build(BuildContext context) {
    final host = ShaderMorphHost.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton(
                onPressed: () => host.forwardByTag(singlePageTagId),
                child: const Text('Forward by tag'),
              ),
              OutlinedButton(
                onPressed: () => host.reverseByTag(singlePageTagId),
                child: const Text('Reverse by tag'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ShaderMorphTag(
            id: singlePageTagId,
            role: ShaderMorphRole.origin,
            trigger: ShaderMorphTrigger.onTapForward,
            child: const _TaskCard(),
          ),
          const Spacer(),
          ShaderMorphTag(
            id: singlePageTagId,
            role: ShaderMorphRole.destination,
            trigger: ShaderMorphTrigger.onTapReverse,
            child: const _CircleMorphTarget(),
          ),
          const SizedBox(height: 16),
          ShaderMorphTag(
            id: crossRouteTagId,
            role: ShaderMorphRole.origin,
            pushTo: const _CrossRouteDestinationPage(tagId: crossRouteTagId),
            transitionConfig: const MorphTransitionConfig(
              interpolation: MorphInterpolation.easeInOut,
              shaderStyle: MorphShaderStyle.standard,
            ),
            child: const _CrossRouteSourceCard(),
          ),
        ],
      ),
    );
  }
}

class _CircleMorphTarget extends StatelessWidget {
  const _CircleMorphTarget();

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=tony'),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1C24),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Meetings & report',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Organizing meetings and reporting to stakeholders.',
            style: TextStyle(color: Colors.white70),
          ),
          SizedBox(height: 16),
          _DestinationRow(),
        ],
      ),
    );
  }
}

class _DestinationRow extends StatelessWidget {
  const _DestinationRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1C24),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=tony'),
          ),
          SizedBox(width: 12),
          Text(
            'Tony Ware',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Spacer(),
          Icon(Icons.chevron_right, color: Colors.white),
        ],
      ),
    );
  }
}

class _CrossRouteSourceCard extends StatelessWidget {
  const _CrossRouteSourceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2B2835),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        children: [
          Icon(Icons.open_in_new, color: Colors.white),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Open Cross-Route Morph',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
        ],
      ),
    );
  }
}

class _CrossRouteDestinationPage extends StatelessWidget {
  final String tagId;

  const _CrossRouteDestinationPage({required this.tagId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111014),
        foregroundColor: Colors.white,
        title: const Text('Cross-Route Destination'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            ShaderMorph.reverseAndPop(context, tagId: tagId);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 80),
            ShaderMorphTag(
              id: tagId,
              role: ShaderMorphRole.destination,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B2835),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cross-Route Morph Active',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This widget is the destination endpoint.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: () {
                ShaderMorph.reverseAndPop(context, tagId: tagId);
              },
              child: const Text('Reverse and Pop'),
            ),
          ],
        ),
      ),
    );
  }
}
