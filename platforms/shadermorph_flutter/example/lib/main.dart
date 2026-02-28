import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(home: MorphDemo()));
}

class MorphDemo extends StatefulWidget {
  const MorphDemo({super.key});

  @override
  State<MorphDemo> createState() => _MorphDemoState();
}

class _MorphDemoState extends State<MorphDemo> {
  bool _isCircle = false;

  @override
  Widget build(BuildContext context) {
    final double width = 120;
    final double height = _isCircle ? 120 : 80;
    final double radius = _isCircle ? width / 2 : 12;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isCircle = !_isCircle;
                });
              },
              child: Text(
                _isCircle ? 'Morph to Rectangle' : 'Morph to Circle',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
