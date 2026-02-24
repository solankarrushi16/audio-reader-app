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
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // App Bar
      appBar: AppBar(
        title: const Text(
          'Audio Reader',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      
      // Body
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Title
            const Text(
              'Upload a File',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            
            const SizedBox(height: 10),
            
            // Subtitle - Supported formats
            const Text(
              'Supports: Word, PDF, Text, Markdown, Images',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            
            const SizedBox(height: 20),
            
            // Supported File Types Icons Row
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    Icon(Icons.description, size: 30, color: Colors.blue),
                    Text('.docx', style: TextStyle(fontSize: 10)),
                  ],
                ),
                SizedBox(width: 15),
                Column(
                  children: [
                    Icon(Icons.picture_as_pdf, size: 30, color: Colors.red),
                    Text('.pdf', style: TextStyle(fontSize: 10)),
                  ],
                ),
                SizedBox(width: 15),
                Column(
                  children: [
                    Icon(Icons.text_snippet, size: 30, color: Colors.green),
                    Text('.txt', style: TextStyle(fontSize: 10)),
                  ],
                ),
                SizedBox(width: 15),
                Column(
                  children: [
                    Icon(Icons.code, size: 30, color: Colors.purple),
                    Text('.md', style: TextStyle(fontSize: 10)),
                  ],
                ),
                SizedBox(width: 15),
                Column(
                  children: [
                    Icon(Icons.image, size: 30, color: Colors.orange),
                    Text('image', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // File Name
            const Text('No file selected'),
            
            const SizedBox(height: 20),
            
            // Select File Button
            ElevatedButton(
              onPressed: () {},
              child: const Text('Select File'),
            ),
            
            const SizedBox(height: 20),
            
            // Text Area
            const Expanded(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(15),
                  child: SingleChildScrollView(
                    child: Text('Extracted text will appear here...'),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
            
            // Audio Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Play Button
                ElevatedButton(
                  onPressed: () {},
                  child: const Icon(Icons.play_arrow),
                ),
                
                const SizedBox(width: 20),
                
                // Stop Button
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Icon(Icons.stop),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
