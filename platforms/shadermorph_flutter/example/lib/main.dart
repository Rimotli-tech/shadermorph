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
        shaderStyle: MorphShaderStyle.soft,
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

  static const String tagId = 'card42';

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
                onPressed: () => host.forwardByTag(tagId),
                child: const Text('Forward by tag'),
              ),
              OutlinedButton(
                onPressed: () => host.reverseByTag(tagId),
                child: const Text('Reverse by tag'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ShaderMorphTag(
            id: tagId,
            role: ShaderMorphRole.source,
            child: const _TaskCard(),
          ),
          const Spacer(),
          ShaderMorphTag(
            id: tagId,
            role: ShaderMorphRole.destination,
            trigger: ShaderMorphTrigger.onTapReverse,
            child: const _DestinationRow(),
          ),
        ],
      ),
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
