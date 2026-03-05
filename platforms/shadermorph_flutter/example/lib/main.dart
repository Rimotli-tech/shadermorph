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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        backgroundColor: const Color.fromARGB(255, 17, 16, 20),
      ),
      backgroundColor: const Color.fromARGB(255, 17, 16, 20),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                const Text(
                  'ShaderMorph Demo',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Chip(
                  backgroundColor: const Color.fromARGB(255, 24, 24, 26),
                  label: const Text(
                    'List',
                    style: TextStyle(color: Colors.white),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                const SizedBox(width: 8),
                Chip(
                  label: const Text('Goals'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: const Text('Hot'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: const Text('Safe'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _taskcard(),
            Spacer(),
            //const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1C24),
                borderRadius: BorderRadius.circular(28),
              ),
              width: 370,
              child: _destinationCard(),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _taskcard() {
  return Container(
    width: 370,
    padding: const EdgeInsets.all(24.0),
    decoration: BoxDecoration(
      color: const Color(0xFF1E1C24),
      borderRadius: BorderRadius.circular(28),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Meetings&report',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Organizing meetings and reporting to stakeholders/investors within the project',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _buildTag('Meetings', const Color(0xFFE6FF6B), Colors.black),
            const SizedBox(width: 12),
            _buildPriorityTag('High priority'),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            _buildInfoColumn(
              'Due date',
              Icons.calendar_month_outlined,
              'Mar 15, 2025',
            ),
            const SizedBox(width: 40),
            _buildInfoColumn(
              'Tracked time',
              Icons.hourglass_empty_rounded,
              '0h 0m',
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=tony'),
            ),
            const SizedBox(width: 12),
            const Text(
              'Tony Ware',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chevron_right, color: Colors.white),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildTag(String text, Color bgColor, Color textColor) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: textColor,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    ),
  );
}

Widget _buildPriorityTag(String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFD94B4B), width: 1),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Color(0xFFD94B4B),
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    ),
  );
}

Widget _buildInfoColumn(String label, IconData icon, String value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    ],
  );
}

Widget _destinationCard() {
  return Row(
    children: [
      const CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=tony'),
      ),
      const SizedBox(width: 12),
      const Text(
        'Tony Ware',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      const Spacer(),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.chevron_right, color: Colors.white),
      ),
    ],
  );
}

//------------------------
