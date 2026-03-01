import 'package:flutter/material.dart';
import 'package:shadermorph_flutter/shadermorph_flutter.dart';

void main() {
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: ExampleApp()),
  );
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Center(
        child: ShaderMorph(
          duration: const Duration(
            milliseconds: 1000,
          ), // Customize speed easily
          child: Container(
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
                "TAP TO MORPH",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
