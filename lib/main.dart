import 'package:flutter/material.dart';

void main() {
  runApp(const AudioReaderApp());
}

class AudioReaderApp extends StatelessWidget {
  const AudioReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio Reader',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Audio Reader'),
        ),
        body: const Center(
          child: Text('Hello Audio Reader!'),
        ),
      ),
    );
  }
}
