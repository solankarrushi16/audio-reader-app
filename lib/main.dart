import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:docx_to_text/docx_to_text.dart';

void main() {
  runApp(const AudioReaderApp());
}

class AudioReaderApp extends StatelessWidget {
  const AudioReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String selectedFileName = "No file selected";
  String extractedText = "";
  bool isPlaying = false;

  final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    flutterTts.setLanguage("en-US");
    flutterTts.setSpeechRate(0.5);
  }

  /// Pick DOCX file and extract text
  Future<void> pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['docx'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        print("File picked: ${file.name}");

        Uint8List? bytes;

        // ✅ For web and other platforms, use bytes directly
        if (file.bytes != null) {
          bytes = file.bytes;
          print("Using file.bytes - File size: ${bytes!.length} bytes");
        }
        // ✅ For mobile platforms, read from path
        else if (file.path != null) {
          File docxFile = File(file.path!);
          bytes = await docxFile.readAsBytes();
          print("Using file.path - File size: ${bytes.length} bytes");
        }

        if (bytes != null && bytes.isNotEmpty) {
          // ✅ Extract text from DOCX
          String text = docxToText(bytes);
          print("Extracted text length: ${text.length}");

          setState(() {
            selectedFileName = file.name;
            extractedText = text.isEmpty ? "File is empty or could not be extracted" : text;
            isPlaying = false;
          });
        } else {
          print("No bytes found for file");
          setState(() {
            selectedFileName = "Error: Could not read file";
            extractedText = "";
          });
        }
      } else {
        print("No file selected or result is null");
      }
    } catch (e) {
      print("Error picking file: $e");
      setState(() {
        selectedFileName = "Error: $e";
        extractedText = "";
      });
    }
  }

  /// Speak extracted text or pause
  Future<void> playAudio() async {
    if (extractedText.isNotEmpty) {
      if (isPlaying) {
        await flutterTts.pause();
        setState(() => isPlaying = false);
      } else {
        await flutterTts.speak(extractedText);
        setState(() => isPlaying = true);
      }
    }
  }

  /// Stop speaking
  Future<void> stopAudio() async {
    await flutterTts.stop();
    setState(() => isPlaying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Audio Reader App"),
        centerTitle: true,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Upload Word File (.docx)",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: pickFile,
              icon: const Icon(Icons.upload_file),
              label: const Text("Select Word File"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: Column(
                children: [
                  const Icon(Icons.description, size: 40, color: Colors.blue),
                  const SizedBox(height: 8),
                  Text(
                    selectedFileName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (extractedText.isNotEmpty) ...[
              const Text(
                "File Content:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        extractedText,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              Expanded(
                child: Center(
                  child: Text(
                    selectedFileName == "No file selected"
                        ? "Select a file to view content"
                        : "Loading...",
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  onPressed: extractedText.isNotEmpty ? playAudio : null,
                  backgroundColor: isPlaying ? Colors.orange : Colors.blue,
                  tooltip: isPlaying ? "Pause" : "Play",
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: extractedText.isNotEmpty ? Colors.white : Colors.grey,
                  ),
                ),
                const SizedBox(width: 16),
                FloatingActionButton(
                  onPressed: stopAudio,
                  backgroundColor: Colors.red,
                  tooltip: "Stop",
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