import 'dart:io';
import 'package:flutter/foundation.dart';
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// ─────────────────────────────────────────────
//  Text cleaning utility
// ─────────────────────────────────────────────
String cleanTextForSpeech(String raw) {
  // 1. Fix soft-hyphen line breaks from PDF ("hyphen-\nnated" → "hyphenated")
  String text = raw.replaceAll(RegExp(r'-\n(?=[a-z])'), '');

  // 2. Collapse multiple blank lines into a single paragraph break marker
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  // 3. Replace lone newlines (mid-paragraph) with a space
  text = text.replaceAll(RegExp(r'(?<!\n)\n(?!\n)'), ' ');

  // 4. Convert bullet/dash list items to sentences with a lead-in pause
  text = text.replaceAll(RegExp(r'^\s*[•\-–—]\s+', multiLine: true), '. ');

  // 5. Convert numbered list items (e.g. "1. ", "2) ") — keep as-is but ensure period+space
  text = text.replaceAllMapped(RegExp(r'^\s*(\d+)[.)]\s+', multiLine: true), (m) => '${m[1]}. ');

  // 6. Collapse multiple spaces
  text = text.replaceAll(RegExp(r'  +'), ' ');

  // 7. Paragraph double-newlines → period + two spaces (TTS natural pause)
  text = text.replaceAll('\n\n', '.  ');

  // 8. Remove special characters that TTS reads as noise (keep punctuation useful for pauses)
  text = text.replaceAll(RegExp(r"[^\w\s.,;:!?()\-]"), ' ');

  // 9. Ensure every sentence ending has a space after the period
  text = text.replaceAll(RegExp(r'\.(?=[A-Z])'), '. ');

  // 10. Final collapse of spaces again after replacements
  text = text.replaceAll(RegExp(r'  +'), ' ').trim();

  return text;
}

// Split cleaned text into chunks ≤ 4000 chars, breaking at sentence boundaries
List<String> chunkText(String text, {int maxLen = 4000}) {
  final List<String> chunks = [];
  while (text.length > maxLen) {
    int cutAt = text.lastIndexOf('. ', maxLen);
    if (cutAt < maxLen ~/ 2) cutAt = text.lastIndexOf(' ', maxLen);
    if (cutAt <= 0) cutAt = maxLen;
    chunks.add(text.substring(0, cutAt + 1).trim());
    text = text.substring(cutAt + 1).trim();
  }
  if (text.isNotEmpty) chunks.add(text.trim());
  return chunks;
}

// ─────────────────────────────────────────────
//  Home Page
// ─────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _fileName = "No file selected";
  String _displayText = "Extracted text will appear here...";
  String _selectedLanguage = "en-US";
  String _selectedSpeed = "Normal";
  int _totalPages = 0;

  bool _isLoading = false;
  bool _isPlaying = false;
  bool _isPaused = false;

  final FlutterTts _tts = FlutterTts();
  List<String> _chunks = [];
  int _currentChunk = 0;

  static const Map<String, double> _speedMap = {
    "Slow": 0.35,
    "Normal": 0.5,
    "Fast": 0.7,
  };

  // ── TTS setup ──────────────────────────────
  @override
  void initState() {
    super.initState();
    _tts.setCompletionHandler(() async {
      // Advance to next chunk automatically
      if (_currentChunk < _chunks.length - 1) {
        _currentChunk++;
        await _speakChunk(_currentChunk);
      } else {
        if (mounted) setState(() { _isPlaying = false; _isPaused = false; });
      }
    });
    _tts.setErrorHandler((msg) {
      if (mounted) setState(() { _isPlaying = false; _isPaused = false; });
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  // ── File picking ───────────────────────────
  Future<void> _selectFile() async {
    setState(() => _isLoading = true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'pdf'],
        withData: true, // ensures bytes are available on all platforms
      );

      if (result == null) { setState(() => _isLoading = false); return; }

      final file = result.files.single;
      final extension = (file.extension ?? '').toLowerCase();
      String rawContent = '';
      int pageCount = 0;

      // ── Read TXT ────────────────────────────
      if (extension == 'txt') {
        if (file.bytes != null) {
          rawContent = String.fromCharCodes(file.bytes!);
        } else if (file.path != null) {
          rawContent = await File(file.path!).readAsString();
        }
      }

      // ── Read PDF ────────────────────────────
      else if (extension == 'pdf') {
        Uint8List? bytes;
        if (file.bytes != null) {
          bytes = file.bytes!;
        } else if (file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }

        if (bytes != null) {
          final document = PdfDocument(inputBytes: bytes);
          pageCount = document.pages.count;
          final extractor = PdfTextExtractor(document);

          // Read ALL pages — no limit
          for (int i = 0; i < pageCount; i++) {
            final pageText = extractor.extractText(
              startPageIndex: i,
              endPageIndex: i, // one page at a time — prevents duplication
            );
            rawContent += '$pageText\n\n';
          }
          document.dispose();
        }
      }

      // ── Clean & chunk ───────────────────────
      final cleaned = rawContent.isEmpty ? '' : cleanTextForSpeech(rawContent);

      setState(() {
        _fileName = file.name;
        _totalPages = pageCount;
        _displayText = cleaned.isEmpty ? 'No readable text found in this file.' : cleaned;
        _chunks = cleaned.isEmpty ? [] : chunkText(cleaned);
        _currentChunk = 0;
        _isPlaying = false;
        _isPaused = false;
      });
    } catch (e) {
      setState(() => _displayText = 'Error reading file: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── TTS controls ───────────────────────────
  Future<void> _speakChunk(int index) async {
    if (index >= _chunks.length) return;
    await _tts.setLanguage(_selectedLanguage);
    await _tts.setSpeechRate(_speedMap[_selectedSpeed]!);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.05); // slightly above 1.0 feels more natural
    await _tts.speak(_chunks[index]);
    if (mounted) setState(() { _isPlaying = true; _isPaused = false; });
  }

  Future<void> _play() async {
    if (_chunks.isEmpty) return;
    await _tts.stop();
    _currentChunk = 0;
    await _speakChunk(0);
  }

  Future<void> _pauseResume() async {
    if (_isPaused) {
      // Resume from the current chunk
      await _speakChunk(_currentChunk);
    } else {
      await _tts.pause();
      setState(() { _isPlaying = false; _isPaused = true; });
    }
  }

  Future<void> _stop() async {
    await _tts.stop();
    setState(() { _isPlaying = false; _isPaused = false; _currentChunk = 0; });
  }

  // ── Build ──────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasText = _displayText != "Extracted text will appear here..." &&
        !_displayText.startsWith('Error') &&
        _chunks.isNotEmpty;

    return Scaffold(
      // ── App bar ─────────────────────────────
      appBar: AppBar(
        title: const Text('Audio Reader'),
        centerTitle: true,
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),

      // ── Drawer ──────────────────────────────
      drawer: Drawer(
        child: ListView(children: [
          DrawerHeader(
            decoration: BoxDecoration(color: colors.primary),
            child: const Text('Menu',
                style: TextStyle(fontSize: 22, color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () => Navigator.pop(context),
          ),
        ]),
      ),

      // ── Body ────────────────────────────────
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── File info row ──────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_fileName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                          overflow: TextOverflow.ellipsis),
                      if (_totalPages > 0)
                        Text('$_totalPages pages',
                            style: TextStyle(
                                fontSize: 12, color: colors.secondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _selectFile,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.upload_file),
                  label: Text(_isLoading ? 'Reading...' : 'Select File'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Settings row ───────────────────
            Row(
              children: [
                // Language
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedLanguage,
                    decoration: const InputDecoration(
                      labelText: 'Language',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'en-US', child: Text('English (US)')),
                      DropdownMenuItem(value: 'en-GB', child: Text('English (UK)')),
                      DropdownMenuItem(value: 'hi-IN', child: Text('Hindi')),
                    ],
                    onChanged: (v) => setState(() => _selectedLanguage = v!),
                  ),
                ),
                const SizedBox(width: 10),
                // Speed
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSpeed,
                    decoration: const InputDecoration(
                      labelText: 'Speed',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Slow', child: Text('Slow')),
                      DropdownMenuItem(value: 'Normal', child: Text('Normal')),
                      DropdownMenuItem(value: 'Fast', child: Text('Fast')),
                    ],
                    onChanged: (v) => setState(() => _selectedSpeed = v!),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Chunk progress ─────────────────
            if (hasText && _chunks.length > 1)
              Text(
                'Section ${_currentChunk + 1} of ${_chunks.length}',
                style: TextStyle(fontSize: 12, color: colors.secondary),
                textAlign: TextAlign.center,
              ),

            if (hasText && _chunks.length > 1) const SizedBox(height: 4),

            if (hasText && _chunks.length > 1)
              LinearProgressIndicator(
                value: (_currentChunk + 1) / _chunks.length,
                minHeight: 4,
                borderRadius: BorderRadius.circular(4),
              ),

            const SizedBox(height: 12),

            // ── Extracted text area ────────────
            Expanded(
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: SingleChildScrollView(
                    child: Text(
                      _displayText,
                      style: const TextStyle(fontSize: 14.5, height: 1.6),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Playback controls ──────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Play
                FilledButton.icon(
                  onPressed: hasText && !_isPlaying ? _play : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play'),
                  style: FilledButton.styleFrom(backgroundColor: colors.primary),
                ),
                const SizedBox(width: 10),

                // Pause / Resume
                FilledButton.icon(
                  onPressed: (_isPlaying || _isPaused) ? _pauseResume : null,
                  icon: Icon(_isPaused ? Icons.play_circle_outline : Icons.pause),
                  label: Text(_isPaused ? 'Resume' : 'Pause'),
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange.shade700),
                ),
                const SizedBox(width: 10),

                // Stop
                FilledButton.icon(
                  onPressed: (_isPlaying || _isPaused) ? _stop : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade600),
                ),
              ],
            ),

            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
