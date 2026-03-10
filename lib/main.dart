import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:docx_to_text/docx_to_text.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReadAloud',
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String fileName = 'No file selected';
  String extractedText = 'Upload a file to see the text here.';
  bool isLoading = false;
  bool isPlaying = false;
  bool isPaused = false;
  int totalPages = 0;

  FlutterTts tts = FlutterTts();
  List<String> chunks = [];
  int currentChunk = 0;

  @override
  void initState() {
    super.initState();

    // This makes sure the completion handler fires correctly on Android
    tts.awaitSpeakCompletion(true);

    // When one chunk finishes, automatically play the next one
    tts.setCompletionHandler(() async {
      if (currentChunk < chunks.length - 1) {
        currentChunk++;
        await speakChunk(currentChunk);
      } else {
        setState(() {
          isPlaying = false;
          isPaused = false;
        });
      }
    });
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  // TTS has a character limit so we split text into smaller pieces
  List<String> splitText(String text) {
    List<String> result = [];
    int maxLen = 3000;

    while (text.length > maxLen) {
      int cutAt = text.lastIndexOf('. ', maxLen);
      if (cutAt < 0) cutAt = maxLen;
      result.add(text.substring(0, cutAt + 1).trim());
      text = text.substring(cutAt + 1).trim();
    }

    if (text.isNotEmpty) result.add(text);
    return result;
  }

  // Clean up text so it sounds better when read aloud
  String cleanText(String text) {
    text = text.replaceAll(RegExp(r'(?<!\n)\n(?!\n)'), ' ');
    text = text.replaceAll('\n\n', '.  ');
    text = text.replaceAll(RegExp(r'^\s*[•\-–—]\s+', multiLine: true), '. ');
    text = text.replaceAll(RegExp(r'  +'), ' ');
    return text.trim();
  }

  Future<void> pickFile() async {
    setState(() => isLoading = true);

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'pdf', 'docx'],
      withData: true,
    );

    if (result == null) {
      setState(() => isLoading = false);
      return;
    }

    final file = result.files.single;
    final ext = (file.extension ?? '').toLowerCase();
    String content = '';
    int pages = 0;

    try {
      if (ext == 'txt') {
        content = String.fromCharCodes(file.bytes!);
      } else if (ext == 'docx') {
        content = docxToText(file.bytes!);
      } else if (ext == 'pdf') {
        PdfDocument doc = PdfDocument(inputBytes: file.bytes!);
        pages = doc.pages.count;
        PdfTextExtractor extractor = PdfTextExtractor(doc);

        for (int i = 0; i < pages; i++) {
          // startPageIndex and endPageIndex must both be set to i
          content += extractor.extractText(startPageIndex: i, endPageIndex: i);
          content += '\n\n';
        }

        doc.dispose();
      }

      setState(() {
        fileName = file.name;
        totalPages = pages;
        extractedText = content.isEmpty ? 'No text found in this file.' : content.trim();
        chunks = splitText(cleanText(content));
        currentChunk = 0;
        isPlaying = false;
        isPaused = false;
      });
    } catch (e) {
      setState(() => extractedText = 'Error reading file: $e');
    }

    setState(() => isLoading = false);
  }

  Future<void> speakChunk(int index) async {
    setState(() {
      isPlaying = true;
      isPaused = false;
    });
    await tts.setLanguage('en-IN');
    await tts.setSpeechRate(0.5);
    await tts.setVolume(1.0);
    await tts.speak(chunks[index]);
  }

  Future<void> playAudio() async {
    if (chunks.isEmpty) return;
    await tts.stop();
    currentChunk = 0;
    await speakChunk(0);
  }

  Future<void> pauseResume() async {
    if (isPaused) {
      await speakChunk(currentChunk);
    } else {
      await tts.pause();
      setState(() {
        isPlaying = false;
        isPaused = true;
      });
    }
  }

  Future<void> stopAudio() async {
    await tts.stop();
    setState(() {
      isPlaying = false;
      isPaused = false;
      currentChunk = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool hasText = chunks.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ReadAloud',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Show supported file formats
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Column(children: [
                  Icon(Icons.description, color: Colors.blue, size: 30),
                  Text('.docx', style: TextStyle(fontSize: 11)),
                ]),
                SizedBox(width: 24),
                Column(children: [
                  Icon(Icons.picture_as_pdf, color: Colors.red, size: 30),
                  Text('.pdf', style: TextStyle(fontSize: 11)),
                ]),
                SizedBox(width: 24),
                Column(children: [
                  Icon(Icons.text_snippet, color: Colors.green, size: 30),
                  Text('.txt', style: TextStyle(fontSize: 11)),
                ]),
              ],
            ),
            const SizedBox(height: 16),

            // File name and upload button
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (totalPages > 0)
                        Text(
                          '$totalPages pages',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isLoading ? null : pickFile,
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: Text(isLoading ? 'Loading...' : 'Select File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Text display area
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      extractedText,
                      style: const TextStyle(fontSize: 14, height: 1.6),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Play / Pause / Stop buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: hasText && !isPlaying ? playAudio : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (isPlaying || isPaused) ? pauseResume : null,
                    icon: Icon(isPaused ? Icons.play_circle_outline : Icons.pause),
                    label: Text(isPaused ? 'Resume' : 'Pause'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (isPlaying || isPaused) ? stopAudio : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
