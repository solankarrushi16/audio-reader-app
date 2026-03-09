import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:docx_to_text/docx_to_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

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
  String selectedVoice = 'Male';
  int totalPages = 0;
  bool isLoading = false;
  bool isPlaying = false;
  bool isPaused = false;
  bool isDownloading = false;

  String currentFilePath = '';
  bool hasPromptedBookmark = false;

  static const String bookmarkFileKey = 'bookmark_file_path';
  static const String bookmarkChunkKey = 'bookmark_chunk_index';
  static const String bookmarkTextKey = 'bookmark_text';

  FlutterTts tts = FlutterTts();
  List<String> chunks = [];
  int currentChunk = 0;
  final ScrollController scrollController = ScrollController();
  List<GlobalKey> chunkScrollKeys = [];
  String currentWord = '';
  int currentWordStart = 0;
  final GlobalKey _scrollAreaKey = GlobalKey();

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
        if (mounted) {
          setState(() {
            isPlaying = false;
            isPaused = false;
            currentWord = '';
          });
        }
      }
    });

    tts.setErrorHandler((msg) {
      if (mounted) {
        setState(() {
          isPlaying = false;
          isPaused = false;
          currentWord = '';
        });
      }
    });

    tts.setProgressHandler((String text, int start, int end, String word) {
      if (mounted) setState(() { currentWord = word; currentWordStart = start; });
    });

    // Check for a saved bookmark to resume
    Future.microtask(() => checkAndPromptBookmark());
  }

  @override
  void dispose() {
    saveBookmark();
    tts.stop();
    scrollController.dispose();
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

    final ttsText = cleanText(savedText);
    final splitChunks = splitIntoChunks(ttsText);
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
                  extractedText = savedText;
                  chunks = splitChunks;
                  chunkScrollKeys = List.generate(splitChunks.length, (_) => GlobalKey());
                  currentChunk = savedChunk < splitChunks.length ? savedChunk : 0;
                  currentWord = '';
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

  // Formats raw text for visual display — preserves paragraphs, spacing, table rows
  String cleanTextForDisplay(String raw) {
    String text = raw;
    // Rejoin hyphenated words broken across lines (e.g. "natu-\nral" → "natural")
    text = text.replaceAllMapped(
      RegExp(r'(\w)-\n([a-z])'),
      (m) => '${m[1]}${m[2]}',
    );
    // Collapse 3+ blank lines to a single paragraph break
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    // Detect table-like rows: lines with 3+ columns separated by 2+ spaces → add | separators
    text = text.split('\n').map((line) {
      final cols = line.trim().split(RegExp(r' {2,}'));
      if (cols.length >= 3 && line.trim().isNotEmpty) {
        return cols.map((c) => c.trim()).where((c) => c.isNotEmpty).join('  |  ');
      }
      return line;
    }).join('\n');
    // Remove trailing whitespace from each line
    text = text.split('\n').map((l) => l.trimRight()).join('\n');
    return text.trim();
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

  // Split text into sentence-level chunks (2-3 sentences each) so user can tap any sentence to play
  List<String> splitIntoChunks(String text) {
    if (text.trim().isEmpty) return [];
    // Split at sentence boundaries
    final List<String> parts = text.split(RegExp(r'(?<=[.!?])\s+'));
    final List<String> result = [];
    String current = '';
    for (final part in parts) {
      final String p = part.trim();
      if (p.isEmpty) continue;
      if (current.isEmpty) {
        current = p;
      } else if (current.length + 1 + p.length <= 500) {
        current = '$current $p';
      } else {
        result.add(current);
        current = p;
      }
    }
    if (current.isNotEmpty) result.add(current);
    return result.isEmpty ? [text.trim()] : result;
  }

  void scrollToCurrentChunk() {
    if (!scrollController.hasClients ||
        chunkScrollKeys.isEmpty ||
        currentChunk >= chunkScrollKeys.length) {
      return;
    }
    final chunkCtx = chunkScrollKeys[currentChunk].currentContext;
    if (chunkCtx == null) return;
    final renderObj = chunkCtx.findRenderObject();
    if (renderObj == null || !renderObj.attached) return;
    try {
      final double offset = RenderAbstractViewport.of(renderObj)
          .getOffsetToReveal(renderObj, 0.2)
          .offset
          .clamp(0.0, scrollController.position.maxScrollExtent);
      if ((offset - scrollController.offset).abs() < 20) return;
      scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } catch (_) {}
  }

  String extractDocx(Uint8List bytes) {
    try {
      return docxToText(bytes);
    } catch (e) {
      return 'Error reading Word file: $e';
    }
  }

  Future<void> selectFile() async {
    setState(() => isLoading = true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'pdf', 'docx', 'jpg', 'jpeg', 'png'],
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
        } else {
          content = 'Unable to read text file.';
        }
      } else if (['jpg', 'jpeg', 'png'].contains(ext)) {
        // Image selected via file picker — run OCR using file path (Android local files always have a valid path)
        setState(() => isLoading = false);
        if (isOcrSupported && file.path != null && file.path!.isNotEmpty) {
          await runOCR(file.path!);
        } else {
          setState(() => extractedText = 'Image reading is only supported on Android/iOS.');
        }
        return;
      } else if (ext == 'docx') {
        if (file.bytes != null) {
          content = extractDocx(file.bytes!);
        } else {
          content = 'Unable to read Word file.';
        }
      } else if (ext == 'pdf') {
        if (file.bytes != null) {
          PdfDocument document = PdfDocument(inputBytes: file.bytes!);
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
        } else {
          content = 'Unable to read PDF file.';
        }
      }

      String displayText = content.isEmpty ? '' : cleanTextForDisplay(content);
      String ttsText = content.isEmpty ? '' : cleanText(content);

      final String newDisplayText = displayText.isEmpty ? 'No readable text found.' : displayText;
      final List<String> newChunks = ttsText.isEmpty ? [] : splitIntoChunks(ttsText);

      setState(() {
        fileName = file.name;
        currentFilePath = file.name;
        totalPages = pages;
        extractedText = newDisplayText;
        chunks = newChunks;
        chunkScrollKeys = List.generate(newChunks.length, (_) => GlobalKey());
        currentChunk = 0;
        currentWord = '';
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
      currentWord = '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => scrollToCurrentChunk());
    await tts.setLanguage(selectedLanguage);
    await tts.setSpeechRate(getSpeed());
    await tts.setVolume(1.0);
    await tts.setPitch(selectedVoice == 'Male' ? 0.80 : 1.15);
    await tts.speak(chunks[index]);
  }

  Future<void> playAudio() async {
    if (chunks.isEmpty) return;
    await tts.stop();
    currentChunk = 0;
    await speakChunk(currentChunk);
    await saveBookmark();
  }

  Future<void> pauseResume() async {
    if (isPaused) {
      await speakChunk(currentChunk);
      await saveBookmark();
    } else {
      await tts.pause();
      setState(() {
        isPlaying = false;
        isPaused = true;
        currentWord = '';
      });
      await saveBookmark();
    }
  }

  Future<void> stopAudio() async {
    await tts.stop();
    setState(() {
      isPlaying = false;
      isPaused = false;
      currentChunk = 0;
      currentWord = '';
    });
  }

  Future<void> tapToPlayFromChunk(int chunkIndex) async {
    if (chunks.isEmpty || chunkIndex >= chunks.length) return;
    await tts.stop();
    setState(() {
      currentChunk = chunkIndex;
      currentWord = '';
      isPlaying = false;
      isPaused = false;
    });
    await speakChunk(chunkIndex);
    await saveBookmark();
  }

  Widget _buildChunkText(int index, bool isCurrent) {
    final String displayText = chunks[index];
    const TextStyle style = TextStyle(fontSize: 14, height: 1.7, color: Color(0xFF2D2D2D));
    if (!isCurrent || currentWord.isEmpty) return Text(displayText, style: style);
    final int chunkLen = displayText.isEmpty ? 1 : displayText.length;
    final double progress = (currentWordStart / chunkLen).clamp(0.0, 1.0);
    final int searchFrom = (progress * displayText.length).round().clamp(0, displayText.length);
    final String lowerDisplay = displayText.toLowerCase();
    final String lowerWord = currentWord.toLowerCase();
    int idx = lowerDisplay.indexOf(lowerWord, searchFrom);
    if (idx < 0 && searchFrom > 0) idx = lowerDisplay.indexOf(lowerWord);
    if (idx < 0 || idx + currentWord.length > displayText.length) return Text(displayText, style: style);
    return RichText(
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: displayText.substring(0, idx)),
          TextSpan(
            text: displayText.substring(idx, idx + currentWord.length),
            style: const TextStyle(
              backgroundColor: Color(0xFFFFEB3B),
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          TextSpan(text: displayText.substring(idx + currentWord.length)),
        ],
      ),
    );
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
          chunkScrollKeys = [];
          currentChunk = 0;
          currentWord = '';
          isPlaying = false;
          isPaused = false;
        });

        await clearBookmark();

        // Speak the message aloud for blind users
        await speakText('No readable text found in the image.');
      } else {
        final String displayText = cleanTextForDisplay(extractedContent);
        final String ttsText = cleanText(extractedContent);
        final List<String> newChunks = splitIntoChunks(ttsText);

        setState(() {
          fileName = "Image (OCR)";
          totalPages = 0;
          extractedText = displayText;
          chunks = newChunks;
          chunkScrollKeys = List.generate(newChunks.length, (_) => GlobalKey());
          currentChunk = 0;
          currentWord = '';
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
        chunkScrollKeys = [];
        currentWord = '';
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

  Future<void> downloadAudio() async {
    if (chunks.isEmpty) return;

    // synthesizeToFile only works on Android
    if (kIsWeb || !Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio download is only available on Android devices.')),
      );
      return;
    }

    setState(() => isDownloading = true);

    try {
      final Directory? extDir = await getExternalStorageDirectory();
      final String dirPath = extDir?.path ?? '/storage/emulated/0/Download';
      final String safeName = fileName
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .toLowerCase();
      final String savePath = '$dirPath/ReadAloud_$safeName.wav';

      await tts.setLanguage(selectedLanguage);
      await tts.setSpeechRate(getSpeed());
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);

      final String fullText = chunks.join(' ');
      final result = await tts.synthesizeToFile(fullText, savePath);

      if (!mounted) return;
      if (result == 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved as ReadAloud_$safeName.wav'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Downloads',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DownloadsPage()),
              ),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save audio. Try on an Android device.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } finally {
      setState(() => isDownloading = false);
    }
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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 36,
              errorBuilder: (e, o, s) => const Icon(Icons.record_voice_over, color: Colors.white),
            ),
            const SizedBox(width: 8),
            const Text(
              'ReadAloud',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        elevation: 3,
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark, color: Colors.white),
            tooltip: 'Bookmark current position',
            onPressed: chunks.isEmpty
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await saveBookmark();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Bookmarked! Position saved.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
          ),
        ],
      ),

      drawer: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.blueAccent,
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 70,
                    errorBuilder: (e, o, s) => const Icon(Icons.record_voice_over, color: Colors.white, size: 56),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ReadAloud',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Document to Speech App',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.home_outlined, color: Colors.blueAccent),
              title: const Text('Home', style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.audio_file_outlined, color: Colors.deepPurple),
              title: const Text('Downloaded Audio', style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DownloadsPage()),
                );
              },
            ),
            const Divider(indent: 16, endIndent: 16),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Deepstambh Foundation\nMonobal • Jalgaon • Pune',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // Format icons row
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(children: [const Icon(Icons.description, size: 28, color: Colors.blue), const SizedBox(height: 2), const Text('.docx', style: TextStyle(fontSize: 10, color: Colors.blue))]),
                  Column(children: [const Icon(Icons.picture_as_pdf, size: 28, color: Colors.red), const SizedBox(height: 2), const Text('.pdf', style: TextStyle(fontSize: 10, color: Colors.red))]),
                  Column(children: [const Icon(Icons.text_snippet, size: 28, color: Colors.green), const SizedBox(height: 2), const Text('.txt', style: TextStyle(fontSize: 10, color: Colors.green))]),
                  Column(children: [const Icon(Icons.image, size: 28, color: Colors.orange), const SizedBox(height: 2), const Text('image', style: TextStyle(fontSize: 10, color: Colors.orange))]),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // File name + select button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blueAccent.withAlpha(80)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (totalPages > 0)
                          Text(
                            '$totalPages pages',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: isLoading ? null : selectFile,
                    icon: isLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.upload_file, size: 18),
                    label: Text(isLoading ? 'Reading...' : 'Select File', style: const TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Scan Image button
            ElevatedButton.icon(
              onPressed: isLoading || !isOcrSupported ? null : showImageSourceDialog,
              icon: const Icon(Icons.photo_camera, size: 18),
              label: const Text('Scan Image / Upload Photo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
            if (!isOcrSupported)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Image scanning available on Android/iOS only.',
                  style: TextStyle(fontSize: 11, color: Colors.redAccent),
                ),
              ),
            const SizedBox(height: 8),

            // Language + voice row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedLanguage,
                    decoration: const InputDecoration(
                      labelText: 'Language',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'en-IN', child: Text('English (India)')),
                      DropdownMenuItem(value: 'hi-IN', child: Text('Hindi')),
                    ],
                    onChanged: (value) => setState(() => selectedLanguage = value!),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Voice', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    const SizedBox(height: 2),
                    ToggleButtons(
                      isSelected: [selectedVoice == 'Male', selectedVoice == 'Female'],
                      onPressed: (i) async {
                        final v = i == 0 ? 'Male' : 'Female';
                        setState(() => selectedVoice = v);
                        if (isPlaying) {
                          await tts.stop();
                          await speakChunk(currentChunk);
                        }
                      },
                      selectedColor: Colors.white,
                      fillColor: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(6),
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 36),
                      children: const [
                        Text('♂ M', style: TextStyle(fontSize: 12)),
                        Text('♀ F', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () async {
                    setState(() => selectedSpeed = 'Slow');
                    if (isPlaying) {
                      await tts.stop();
                      await speakChunk(currentChunk);
                    }
                  },
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
                  onTap: () async {
                    setState(() => selectedSpeed = 'Normal');
                    if (isPlaying) {
                      await tts.stop();
                      await speakChunk(currentChunk);
                    }
                  },
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
                  onTap: () async {
                    setState(() => selectedSpeed = 'Fast');
                    if (isPlaying) {
                      await tts.stop();
                      await speakChunk(currentChunk);
                    }
                  },
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

            // Extracted text card
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F0FE),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.article_outlined, size: 16, color: Colors.blueAccent),
                          const SizedBox(width: 6),
                          const Text('Extracted Text', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                          const Spacer(),
                          if (isPlaying)
                            Row(children: [
                              const SizedBox(width: 6, height: 6, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.blueAccent)),
                              const SizedBox(width: 6),
                              Text(
                                currentWord.isNotEmpty ? '"$currentWord"' : 'Reading...',
                                style: const TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                              ),
                            ])
                          else if (chunks.isNotEmpty)
                            const Text('Tap any sentence to play from there', style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        key: _scrollAreaKey,
                        controller: scrollController,
                        padding: const EdgeInsets.all(12),
                        child: chunks.isEmpty
                            ? SelectableText(
                                extractedText,
                                style: const TextStyle(fontSize: 14, height: 1.7, color: Color(0xFF2D2D2D)),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: List.generate(chunks.length, (i) {
                                  final bool isCurrent = i == currentChunk && isPlaying;
                                  return InkWell(
                                    onTap: () => tapToPlayFromChunk(i),
                                    borderRadius: BorderRadius.circular(6),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      key: i < chunkScrollKeys.length ? chunkScrollKeys[i] : null,
                                      margin: const EdgeInsets.only(bottom: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isCurrent ? const Color(0xFFE3F2FD) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                        border: isCurrent ? Border.all(color: Colors.blueAccent, width: 1.5) : null,
                                      ),
                                      child: _buildChunkText(i, isCurrent),
                                    ),
                                  );
                                }),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: hasText && !isPlaying ? playAudio : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 50),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (isPlaying || isPaused) ? pauseResume : null,
                    icon: Icon(
                      isPaused ? Icons.play_circle_outline : Icons.pause,
                    ),
                    label: Text(isPaused ? 'Resume' : 'Pause'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 50),
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
                      minimumSize: const Size(0, 50),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: (hasText && !isDownloading && !isPlaying)
                  ? downloadAudio
                  : null,
              icon: isDownloading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download),
              label: Text(isDownloading ? 'Saving Audio...' : 'Download as Audio'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 46),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

// ==================== Downloads Page ====================

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  List<File> audioFiles = [];
  final AudioPlayer audioPlayer = AudioPlayer();
  String? playingPath;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    loadFiles();
    audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() { isPlaying = false; playingPath = null; });
    });
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  Future<void> loadFiles() async {
    if (kIsWeb || !Platform.isAndroid) {
      if (mounted) setState(() => audioFiles = []);
      return;
    }
    final Directory? extDir = await getExternalStorageDirectory();
    final String dirPath = extDir?.path ?? '/storage/emulated/0/Download';
    final Directory folder = Directory(dirPath);
    if (!await folder.exists()) return;
    final List<File> files = folder
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.wav') || f.path.endsWith('.mp3'))
        .toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    if (mounted) setState(() => audioFiles = files);
  }

  String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> togglePlay(String path) async {
    if (playingPath == path && isPlaying) {
      await audioPlayer.pause();
      setState(() => isPlaying = false);
    } else {
      await audioPlayer.stop();
      await audioPlayer.play(DeviceFileSource(path));
      setState(() { playingPath = path; isPlaying = true; });
    }
  }

  Future<void> deleteFile(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Delete "${file.path.split('/').last}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      if (playingPath == file.path) await audioPlayer.stop();
      await file.delete();
      loadFiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Downloaded Audio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        elevation: 3,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: loadFiles,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: audioFiles.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.audio_file_outlined, size: 72, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('No downloaded audio yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 6),
                  const Text('Download audio from the main screen', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: audioFiles.length,
              itemBuilder: (context, index) {
                final file = audioFiles[index];
                final stat = file.statSync();
                final name = file.path.split('/').last;
                final thisPlaying = playingPath == file.path && isPlaying;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
                    border: thisPlaying ? Border.all(color: Colors.deepPurple, width: 1.5) : null,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: GestureDetector(
                      onTap: () => togglePlay(file.path),
                      child: CircleAvatar(
                        backgroundColor: thisPlaying ? Colors.deepPurple : Colors.deepPurple.withAlpha(25),
                        child: Icon(
                          thisPlaying ? Icons.pause : Icons.play_arrow,
                          color: thisPlaying ? Colors.white : Colors.deepPurple,
                        ),
                      ),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${formatSize(stat.size)}  •  ${formatDate(stat.modified)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => deleteFile(file),
                    ),
                    onTap: () => togglePlay(file.path),
                  ),
                );
              },
            ),
    );
  }
}
