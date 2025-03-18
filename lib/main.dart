import 'package:flutter/material.dart';
import 'map_page.dart'; // Import the MapParentWidget

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter MapLibre Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: MapParentWidget(), // Use the MapParentWidget as the home screen
    );
  }
}