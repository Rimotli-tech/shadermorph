import 'package:flutter/material.dart';
import 'package:shadermorph_flutter/shadermorph_flutter.dart';

void main() {
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: ExampleApp()),
  );
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Center(
        child: ShaderMorph(
          duration: const Duration(
            milliseconds: 1000,
          ), // Customize speed easily
          destination: _buildMorphCard_2(),
          source: _buildMorphCard(),
        ),
      ),
    );
  }
}
