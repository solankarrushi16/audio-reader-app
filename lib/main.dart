import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:docx_to_text/docx_to_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const AudioReaderApp());
}

class AudioReaderApp extends StatelessWidget {
  const AudioReaderApp({super.key});

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
  String fileName = "No file selected";
  String extractedText = "Extracted text will appear here...";
  String selectedLanguage = "en-IN";
  String selectedSpeed = "Normal";
  int totalPages = 0;
  bool isLoading = false;
  bool isPlaying = false;
  bool isPaused = false;

  String currentFilePath = '';
  bool hasPromptedBookmark = false;

  static const String bookmarkFileKey = 'bookmark_file_path';
  static const String bookmarkChunkKey = 'bookmark_chunk_index';
  static const String bookmarkTextKey = 'bookmark_text';

  FlutterTts tts = FlutterTts();
  List<String> chunks = [];
  int currentChunk = 0;

  // ML Kit OCR is only supported on Android/iOS (not web/desktop)
  bool get isOcrSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();

    // awaitSpeakCompletion(true) is required so the completion handler fires correctly on Android
    tts.awaitSpeakCompletion(true);

    tts.setCompletionHandler(() async {
      if (currentChunk < chunks.length - 1) {
        currentChunk++;
        await speakChunk(currentChunk);
      } else {
        if (mounted)
          setState(() {
            isPlaying = false;
            isPaused = false;
          });
      }
    });

    tts.setErrorHandler((msg) {
      if (mounted)
        setState(() {
          isPlaying = false;
          isPaused = false;
        });
    });

    // Check for a saved bookmark to resume
    Future.microtask(() => checkAndPromptBookmark());
  }

  @override
  void dispose() {
    // Save bookmark on exit if there is progress
    saveBookmark();
    tts.stop();
    super.dispose();
  }

  // Bookmark helpers
  Future<void> saveBookmark() async {
    if (extractedText.isEmpty || chunks.isEmpty || currentFilePath.isEmpty) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(bookmarkFileKey, currentFilePath);
      await prefs.setInt(bookmarkChunkKey, currentChunk);
      await prefs.setString(bookmarkTextKey, extractedText);
    } catch (_) {
      // Ignore persistence errors silently to avoid breaking UX.
    }
  }

  Future<void> clearBookmark() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(bookmarkFileKey);
      await prefs.remove(bookmarkChunkKey);
      await prefs.remove(bookmarkTextKey);
    } catch (_) {}
  }

  String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    return parts.isNotEmpty ? parts.last : path;
  }

  Future<void> checkAndPromptBookmark() async {
    if (hasPromptedBookmark) return;
    hasPromptedBookmark = true;

    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString(bookmarkFileKey);
    final savedText = prefs.getString(bookmarkTextKey);
    final savedChunk = prefs.getInt(bookmarkChunkKey) ?? 0;

    if (savedPath == null || savedText == null) return;
    if (!mounted) return;

    final cleaned = cleanText(savedText);
    final splitChunks = splitIntoChunks(cleaned);
    if (splitChunks.isEmpty) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Resume Reading?'),
          content: Text(
            'Continue from your last position in ${_fileNameFromPath(savedPath)}?',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await clearBookmark();
                await speakText('Starting fresh.');
              },
              child: const Text('Start Over'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                if (!mounted) return;
                setState(() {
                  currentFilePath = savedPath;
                  fileName = _fileNameFromPath(savedPath);
                  extractedText = cleaned;
                  chunks = splitChunks;
                  currentChunk = savedChunk < splitChunks.length
                      ? savedChunk
                      : 0;
                  isPlaying = false;
                  isPaused = false;
                });
                await speakText('Resuming your previous reading.');
                await speakChunk(currentChunk);
              },
              child: const Text('Resume'),
            ),
          ],
        );
      },
    );
  }

  // Cleans extracted text so it sounds natural when read aloud
  String cleanText(String raw) {
    String text = raw;

    // Rejoin words split across lines by a hyphen (e.g. "natu-\nral" → "natural")
    text = text.replaceAll(RegExp(r'-\n(?=[a-z])'), '');

    text = text.replaceAll(RegExp(r'(?<!\n)\n(?!\n)'), ' ');
    text = text.replaceAll('\n\n', '.  ');
    text = text.replaceAll(RegExp(r'^\s*[•\-–—]\s+', multiLine: true), '. ');
    text = text.replaceAll(RegExp(r'  +'), ' ');

    return text.trim();
  }

  // TTS has a character limit — split into 3000-char chunks to avoid audio cutoff
  List<String> splitIntoChunks(String text) {
    List<String> result = [];
    int maxLength = 3000;

    while (text.length > maxLength) {
      int cutAt = text.lastIndexOf('. ', maxLength);
      if (cutAt < 500) cutAt = text.lastIndexOf(' ', maxLength);
      if (cutAt <= 0) cutAt = maxLength;
      result.add(text.substring(0, cutAt + 1).trim());
      text = text.substring(cutAt + 1).trim();
    }

    if (text.isNotEmpty) result.add(text.trim());
    return result;
  }

  Future<String> extractDocx(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final text = await docxToText(bytes);
      return text;
    } catch (e) {
      return 'Error reading Word file: $e';
    }
  }

  Future<void> selectFile() async {
    setState(() => isLoading = true);

    try {
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

      if (ext == 'txt') {
        if (file.bytes != null) {
          content = String.fromCharCodes(file.bytes!);
        } else if (file.path != null) {
          content = await File(file.path!).readAsString();
        }
      } else if (ext == 'docx') {
        if (file.path != null && file.path!.isNotEmpty) {
          content = await extractDocx(file.path!);
        } else {
          content = 'Unable to read Word file: missing file path.';
        }
      } else if (ext == 'pdf') {
        Uint8List? bytes;
        if (file.bytes != null) {
          bytes = file.bytes!;
        } else if (file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }

        if (bytes != null) {
          PdfDocument document = PdfDocument(inputBytes: bytes);
          pages = document.pages.count;
          PdfTextExtractor extractor = PdfTextExtractor(document);

          for (int i = 0; i < pages; i++) {
            // startPageIndex and endPageIndex must both be set to i — otherwise text duplicates
            content += extractor.extractText(
              startPageIndex: i,
              endPageIndex: i,
            );
            content += '\n\n';
          }

          document.dispose();
        }
      }

      String cleaned = content.isEmpty ? '' : cleanText(content);

      setState(() {
        fileName = file.name;
        currentFilePath = file.path ?? '';
        totalPages = pages;
        extractedText = cleaned.isEmpty ? 'No readable text found.' : cleaned;
        chunks = cleaned.isEmpty ? [] : splitIntoChunks(cleaned);
        currentChunk = 0;
        isPlaying = false;
        isPaused = false;
      });
    } catch (e) {
      setState(() => extractedText = 'Error reading file: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  double getSpeed() {
    if (selectedSpeed == 'Slow') return 0.35;
    if (selectedSpeed == 'Fast') return 0.7;
    return 0.5;
  }

  Future<void> speakChunk(int index) async {
    if (index >= chunks.length) return;
    setState(() {
      isPlaying = true;
      isPaused = false;
    });
    await tts.setLanguage(selectedLanguage);
    await tts.setSpeechRate(getSpeed());
    await tts.setVolume(1.0);
    await tts.setPitch(1.0);
    await tts.speak(chunks[index]);
  }

  Future<void> playAudio() async {
    if (chunks.isEmpty) return;
    await tts.stop();
    currentChunk = 0;
    await speakText('Starting reading.');
    await speakChunk(currentChunk);
    await saveBookmark();
  }

  Future<void> pauseResume() async {
    if (isPaused) {
      await speakText('Resuming.');
      await speakChunk(currentChunk);
      await saveBookmark();
    } else {
      await tts.pause();
      setState(() {
        isPlaying = false;
        isPaused = true;
      });
      await saveBookmark();
      await speakText('Paused. You can resume.');
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

  // ==================== OCR Image Reading Feature ====================

  /// Pick an image from camera or gallery
  Future<void> pickImage(ImageSource source) async {
    if (!isOcrSupported) {
      const msg = 'Image scanning works only on Android or iOS devices.';
      setState(() {
        extractedText = msg;
        chunks = [];
      });
      await speakText(msg);
      return;
    }

    setState(() => isLoading = true);

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 85, // Optimize image quality for OCR
      );

      if (pickedFile == null) {
        setState(() => isLoading = false);
        return;
      }

      // Run OCR on the selected image
      await runOCR(pickedFile.path);
    } catch (e) {
      setState(() {
        extractedText = 'Error picking image: $e';
        isLoading = false;
      });
    }
  }

  /// Extract text from image using Google ML Kit Text Recognition
  Future<void> runOCR(String imagePath) async {
    currentFilePath = imagePath;
    if (!isOcrSupported) {
      const msg = 'Image scanning works only on Android or iOS devices.';
      setState(() {
        extractedText = msg;
        chunks = [];
      });
      await speakText(msg);
      return;
    }

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );

      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );

      String extractedContent = recognizedText.text;

      // Clean up the recognizer
      textRecognizer.close();

      if (extractedContent.isEmpty) {
        // No text detected - speak a message to the user
        setState(() {
          fileName = "Image (No text found)";
          totalPages = 0;
          extractedText = 'No readable text found in the image.';
          chunks = [];
          currentChunk = 0;
          isPlaying = false;
          isPaused = false;
        });

        await clearBookmark();

        // Speak the message aloud for blind users
        await speakText('No readable text found in the image.');
      } else {
        // Text found - clean and prepare it for speech
        String cleaned = cleanText(extractedContent);

        setState(() {
          fileName = "Image (OCR)";
          totalPages = 0;
          extractedText = cleaned;
          chunks = splitIntoChunks(cleaned);
          currentChunk = 0;
          isPlaying = false;
          isPaused = false;
        });

        await clearBookmark();

        // Automatically speak the extracted text
        if (chunks.isNotEmpty) {
          await playAudio();
        }
      }
    } catch (e) {
      setState(() {
        extractedText = 'Error during OCR: $e';
        chunks = [];
      });
      await speakText('Error reading image. Please try again.');
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// Speak a single text message (used for notifications/errors)
  Future<void> speakText(String text) async {
    await tts.setLanguage(selectedLanguage);
    await tts.setSpeechRate(getSpeed());
    await tts.setVolume(1.0);
    await tts.setPitch(1.0);
    await tts.speak(text);
  }

  /// Show dialog to choose between camera and gallery
  void showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Scan Image'),
          content: const Text('Choose image source:'),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Camera'),
              onPressed: () {
                Navigator.pop(context);
                pickImage(ImageSource.camera);
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.photo_library),
              label: const Text('Gallery'),
              onPressed: () {
                Navigator.pop(context);
                pickImage(ImageSource.gallery);
              },
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  // ===================================================================

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

      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blueAccent),
              child: Text(
                'Menu',
                style: TextStyle(
                  fontSize: 22,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Upload a File',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Supports: Word, PDF, Text, Markdown, Images',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    const Icon(Icons.description, size: 30, color: Colors.blue),
                    const Text('.docx', style: TextStyle(fontSize: 10)),
                  ],
                ),
                const SizedBox(width: 16),
                Column(
                  children: [
                    const Icon(
                      Icons.picture_as_pdf,
                      size: 30,
                      color: Colors.red,
                    ),
                    const Text('.pdf', style: TextStyle(fontSize: 10)),
                  ],
                ),
                const SizedBox(width: 16),
                Column(
                  children: [
                    const Icon(
                      Icons.text_snippet,
                      size: 30,
                      color: Colors.green,
                    ),
                    const Text('.txt', style: TextStyle(fontSize: 10)),
                  ],
                ),
                const SizedBox(width: 16),
                Column(
                  children: [
                    const Icon(Icons.code, size: 30, color: Colors.purple),
                    const Text('.md', style: TextStyle(fontSize: 10)),
                  ],
                ),
                const SizedBox(width: 16),
                Column(
                  children: [
                    const Icon(Icons.image, size: 30, color: Colors.orange),
                    const Text('image', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (totalPages > 0)
                        Text(
                          '$totalPages pages',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isLoading ? null : selectFile,
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: Text(isLoading ? 'Reading...' : 'Select File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Scan Image button for OCR feature
            ElevatedButton.icon(
              onPressed: isLoading || !isOcrSupported
                  ? null
                  : showImageSourceDialog,
              icon: const Icon(Icons.photo_camera),
              label: const Text('Scan Image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            if (!isOcrSupported)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Image scanning is available on Android/iOS devices only.',
                  style: TextStyle(fontSize: 12, color: Colors.redAccent),
                ),
              ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: selectedLanguage,
              decoration: const InputDecoration(
                labelText: 'Language',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'en-IN',
                  child: Text('English (India)'),
                ),
                DropdownMenuItem(value: 'hi-IN', child: Text('Hindi')),
                DropdownMenuItem(value: 'en-US', child: Text('English (US)')),
                DropdownMenuItem(value: 'en-GB', child: Text('English (UK)')),
              ],
              onChanged: (value) => setState(() => selectedLanguage = value!),
            ),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => setState(() => selectedSpeed = 'Slow'),
                  child: Column(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selectedSpeed == 'Slow'
                              ? Colors.blueAccent
                              : Colors.white,
                          border: Border.all(
                            color: selectedSpeed == 'Slow'
                                ? Colors.blueAccent
                                : Colors.grey,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.speed,
                          color: selectedSpeed == 'Slow'
                              ? Colors.white
                              : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Slow',
                        style: TextStyle(
                          fontSize: 12,
                          color: selectedSpeed == 'Slow'
                              ? Colors.blueAccent
                              : Colors.grey,
                          fontWeight: selectedSpeed == 'Slow'
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),

                GestureDetector(
                  onTap: () => setState(() => selectedSpeed = 'Normal'),
                  child: Column(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selectedSpeed == 'Normal'
                              ? Colors.blueAccent
                              : Colors.white,
                          border: Border.all(
                            color: selectedSpeed == 'Normal'
                                ? Colors.blueAccent
                                : Colors.grey,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.play_circle_outline,
                          color: selectedSpeed == 'Normal'
                              ? Colors.white
                              : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Normal',
                        style: TextStyle(
                          fontSize: 12,
                          color: selectedSpeed == 'Normal'
                              ? Colors.blueAccent
                              : Colors.grey,
                          fontWeight: selectedSpeed == 'Normal'
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),

                GestureDetector(
                  onTap: () => setState(() => selectedSpeed = 'Fast'),
                  child: Column(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selectedSpeed == 'Fast'
                              ? Colors.blueAccent
                              : Colors.white,
                          border: Border.all(
                            color: selectedSpeed == 'Fast'
                                ? Colors.blueAccent
                                : Colors.grey,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.fast_forward,
                          color: selectedSpeed == 'Fast'
                              ? Colors.white
                              : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fast',
                        style: TextStyle(
                          fontSize: 12,
                          color: selectedSpeed == 'Fast'
                              ? Colors.blueAccent
                              : Colors.grey,
                          fontWeight: selectedSpeed == 'Fast'
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    child: Text(
                      extractedText,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: hasText && !isPlaying ? playAudio : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),

                ElevatedButton.icon(
                  onPressed: (isPlaying || isPaused) ? pauseResume : null,
                  icon: Icon(
                    isPaused ? Icons.play_circle_outline : Icons.pause,
                  ),
                  label: Text(isPaused ? 'Resume' : 'Pause'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),

                ElevatedButton.icon(
                  onPressed: (isPlaying || isPaused) ? stopAudio : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
