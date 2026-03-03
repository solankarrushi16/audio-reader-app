import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

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

  String fileName = "No file selected";
  String extractedText = "Extracted text will appear here...";
  String selectedLanguage = "en-US";

  FlutterTts tts = FlutterTts();

  Future<void> selectFile() async {

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'pdf'],
    );

    if (result != null) {

      File file = File(result.files.single.path!);
      String extension = result.files.single.extension ?? "";
      String content = "";

      if (extension == "txt") {
        content = await file.readAsString();
      }

      if (extension == "pdf") {
        final bytes = file.readAsBytesSync();
        PdfDocument document = PdfDocument(inputBytes: bytes);

        for (int i = 0; i < document.pages.count; i++) {
          content += PdfTextExtractor(document)
              .extractText(startPageIndex: i);
        }

        document.dispose();
      }

      setState(() {
        fileName = result.files.single.name;
        extractedText = content.isEmpty
            ? "No readable text found"
            : content;
      });
    }
  }

  Future<void> playAudio() async {
    await tts.stop();
    await tts.setLanguage(selectedLanguage);
    await tts.setSpeechRate(0.5);
    await tts.speak(extractedText);
  }

  Future<void> stopAudio() async {
    await tts.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Reader'),
        centerTitle: true,
      ),
      drawer: Drawer(
        child: ListView(
          children: const [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.lightGreen,
              ),
              child: Text(
                "My Menu",
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text("Home"),
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text("Settings"),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Upload a File',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            Text(fileName),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: selectFile,
              child: const Text('Select TXT or PDF File'),
            ),
            const SizedBox(height: 20),
            DropdownButton<String>(
              value: selectedLanguage,
              items: const [
                DropdownMenuItem(
                  value: "en-US",
                  child: Text("English"),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  selectedLanguage = value!;
                });
              },
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: SingleChildScrollView(
                    child: Text(extractedText),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: playAudio,
                  child: const Icon(Icons.play_arrow),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: stopAudio,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
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