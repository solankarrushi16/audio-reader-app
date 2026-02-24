# 🎧 Audio Reader App - Team Development Plan

## 📋 Project Information
- **App Name:** Audio Reader
- **Purpose:** Text-to-Speech app for reading multiple file formats aloud
- **Team Size:** 4 Members
- **Total Phases:** 20 (5 phases per member)
- **Complexity Level:** Simple to Medium

---

## 📁 Supported File Formats

| Format | Extension | Package Used |
|--------|-----------|--------------|
| Word Document | .docx | docx_to_text |
| PDF | .pdf | syncfusion_flutter_pdf |
| Plain Text | .txt | dart:io (built-in) |
| Markdown | .md | dart:io (built-in) |
| Images (OCR) | .jpg, .png | google_mlkit_text_recognition |

---

## 👥 Team Member Distribution

| Member | Phases Assigned | Focus Area |
|--------|-----------------|------------|
| **Member 1** | 1, 5, 9, 13, 17 | Structure, State, TTS, Navigation, PDF Support |
| **Member 2** | 2, 6, 10, 14, 18 | App Shell, Buttons, Audio Controls, Settings UI, Image OCR |
| **Member 3** | 3, 7, 11, 15, 19 | Widgets, File Picker, Styling, Provider, Dark Mode |
| **Member 4** | 4, 8, 12, 16, 20 | Layouts, DOCX Extract, Custom Widgets, Storage, Testing |

---

## 📊 Difficulty Balance

Each member gets: **2 Easy + 2 Medium + 1 Challenging**

| Member | Easy | Medium | Challenging |
|--------|------|--------|-------------|
| Member 1 | Phase 1, 5 | Phase 9, 13 | Phase 17 |
| Member 2 | Phase 2, 6 | Phase 10, 14 | Phase 18 |
| Member 3 | Phase 3, 7 | Phase 11, 15 | Phase 19 |
| Member 4 | Phase 4, 8 | Phase 12, 16 | Phase 20 |

---

## 🔄 Phase Execution Order

**IMPORTANT:** Phases must be completed in order (1 → 2 → 3 → ... → 20)
After each phase, the app should run without errors!

---

## 📝 All 20 Phases - Detailed

---

### 🟢 PHASE 1 - Clean Project Structure
**Assigned to:** Member 1  
**Difficulty:** ⭐ Easy  
**Prerequisite:** None

**What to do:**
1. Create folder structure inside `lib/`:
   - `lib/screens/`
   - `lib/widgets/`
   - `lib/services/`
   - `lib/models/`
   - `lib/utils/`

2. Clean `main.dart` to minimal "Hello Audio Reader" code

**App Status After:** App runs with basic text

---

### 🟢 PHASE 2 - Basic App Shell
**Assigned to:** Member 2  
**Difficulty:** ⭐ Easy  
**Prerequisite:** Phase 1

**What to do:**
1. Setup MaterialApp with `debugShowCheckedModeBanner: false`
2. Create HomePage widget
3. Add AppBar with centered title

**App Status After:** App shows AppBar and body

---

### 🟢 PHASE 3 - Basic Widgets & Layout
**Assigned to:** Member 3  
**Difficulty:** ⭐ Easy  
**Prerequisite:** Phase 2

**What to do:**
1. Add title Text "Upload a File"
2. Add subtitle showing supported formats
3. Add file type icons row (Word, PDF, TXT, MD, Image)
4. Add "No file selected" text

**App Status After:** App shows file type icons and text

---

### 🟢 PHASE 4 - Layout & Spacing
**Assigned to:** Member 4  
**Difficulty:** ⭐ Easy  
**Prerequisite:** Phase 3

**What to do:**
1. Add Padding around content
2. Add SizedBox for spacing
3. Add Card for text display area
4. Add Row for audio control buttons (placeholder)

**App Status After:** Complete basic layout

---

### 🟢 PHASE 5 - Stateful Widget
**Assigned to:** Member 1  
**Difficulty:** ⭐ Easy  
**Prerequisite:** Phase 4

**What to do:**
1. Create `lib/screens/home_screen.dart`
2. Move HomePage to separate file
3. Convert to StatefulWidget
4. Add state variables:
   - `String selectedFileName = 'No file selected';`
   - `String extractedText = '';`
   - `String fileType = '';`

**App Status After:** Code organized with state variables

---

### 🟢 PHASE 6 - Button Widgets
**Assigned to:** Member 2  
**Difficulty:** ⭐ Easy  
**Prerequisite:** Phase 5

**What to do:**
1. Add "Select File" ElevatedButton
2. Add Play ElevatedButton with icon
3. Add Stop ElevatedButton with icon
4. Add `isPlaying` state variable
5. Use setState to update UI on button press (test with dummy data)

**App Status After:** Buttons work with dummy data

---

### 🟢 PHASE 7 - File Picker Integration
**Assigned to:** Member 3  
**Difficulty:** ⭐⭐ Medium  
**Prerequisite:** Phase 6

**What to do:**
1. Add `file_picker` package to pubspec.yaml
2. Run `flutter pub get`
3. Implement file picking for multiple types:

```dart
FilePickerResult? result = await FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: ['docx', 'pdf', 'txt', 'md', 'jpg', 'png', 'jpeg'],
);
```

4. Detect file type from extension
5. Display selected file name

**App Status After:** User can select files of any supported type

---

### 🟡 PHASE 8 - DOCX Text Extraction
**Assigned to:** Member 4  
**Difficulty:** ⭐⭐ Medium  
**Prerequisite:** Phase 7

**What to do:**
1. Add `docx_to_text` package
2. Extract text from .docx files:

```dart
if (fileName.endsWith('.docx')) {
  final bytes = await File(path).readAsBytes();
  extractedText = docxToText(bytes);
}
```

3. Display extracted text in Card

**App Status After:** App can read Word documents

---

### 🟡 PHASE 9 - Basic Text-to-Speech
**Assigned to:** Member 1  
**Difficulty:** ⭐⭐ Medium  
**Prerequisite:** Phase 8

**What to do:**
1. Add `flutter_tts` package
2. Initialize TTS in initState
3. Implement speak() function
4. Connect to Play button

```dart
final FlutterTts flutterTts = FlutterTts();

Future<void> speak() async {
  await flutterTts.setLanguage("en-US");
  await flutterTts.speak(extractedText);
}
```

**App Status After:** App reads Word docs aloud

---

### 🟡 PHASE 10 - Audio Controls
**Assigned to:** Member 2  
**Difficulty:** ⭐⭐ Medium  
**Prerequisite:** Phase 9

**What to do:**
1. Implement play/pause toggle
2. Implement stop function
3. Update button icons based on state
4. Add TTS completion callback

```dart
Future<void> togglePlayPause() async {
  if (isPlaying) {
    await flutterTts.pause();
  } else {
    await flutterTts.speak(extractedText);
  }
  setState(() => isPlaying = !isPlaying);
}
```

**App Status After:** Full audio controls working

---

### 🟡 PHASE 11 - Basic Styling
**Assigned to:** Member 3  
**Difficulty:** ⭐⭐ Medium  
**Prerequisite:** Phase 10

**What to do:**
1. Add ThemeData to MaterialApp
2. Style AppBar with colors
3. Style buttons
4. Style Card with proper colors
5. Add colors to file type icons

**App Status After:** App looks polished

---

### 🟡 PHASE 12 - TXT & MD File Support
**Assigned to:** Member 4  
**Difficulty:** ⭐⭐ Medium  
**Prerequisite:** Phase 11

**What to do:**
1. Add support for .txt files:
```dart
if (fileName.endsWith('.txt') || fileName.endsWith('.md')) {
  extractedText = await File(path).readAsString();
}
```

2. Both TXT and MD are plain text, read directly
3. Test with sample files

**App Status After:** App reads TXT and MD files

---

### 🟡 PHASE 13 - Navigation (Settings Screen)
**Assigned to:** Member 1  
**Difficulty:** ⭐⭐ Medium  
**Prerequisite:** Phase 12

**What to do:**
1. Create `lib/screens/settings_screen.dart`
2. Add settings icon in AppBar
3. Implement Navigator.push to settings
4. Add back button

**App Status After:** Can navigate to Settings and back

---

### 🟡 PHASE 14 - Settings Screen UI
**Assigned to:** Member 2  
**Difficulty:** ⭐⭐ Medium  
**Prerequisite:** Phase 13

**What to do:**
1. Add Slider for speech rate (0.25 to 1.5)
2. Add Slider for pitch (0.5 to 2.0)
3. Add Switch for dark mode
4. Use ListTile for each setting

**App Status After:** Settings screen with controls

---

### 🟡 PHASE 15 - State Management (Provider)
**Assigned to:** Member 3  
**Difficulty:** ⭐⭐⭐ Challenging  
**Prerequisite:** Phase 14

**What to do:**
1. Add `provider` package
2. Create `lib/utils/settings_provider.dart`:

```dart
class SettingsProvider extends ChangeNotifier {
  double _speechRate = 0.5;
  double _pitch = 1.0;
  bool _isDarkMode = false;
  
  // Getters and setters with notifyListeners()
}
```

3. Wrap app with ChangeNotifierProvider
4. Connect settings UI to provider

**App Status After:** Settings work across app

---

### 🟡 PHASE 16 - Local Storage
**Assigned to:** Member 4  
**Difficulty:** ⭐⭐⭐ Challenging  
**Prerequisite:** Phase 15

**What to do:**
1. Add `shared_preferences` package
2. Save settings to storage
3. Load settings on app start

```dart
Future<void> loadSettings() async {
  final prefs = await SharedPreferences.getInstance();
  _speechRate = prefs.getDouble('speechRate') ?? 0.5;
  _isDarkMode = prefs.getBool('isDarkMode') ?? false;
}
```

**App Status After:** Settings persist after restart

---

### 🟠 PHASE 17 - PDF File Support
**Assigned to:** Member 1  
**Difficulty:** ⭐⭐⭐ Challenging  
**Prerequisite:** Phase 16

**What to do:**
1. Add `syncfusion_flutter_pdf` package
2. Extract text from PDF:

```dart
import 'package:syncfusion_flutter_pdf/pdf.dart';

if (fileName.endsWith('.pdf')) {
  final bytes = await File(path).readAsBytes();
  PdfDocument document = PdfDocument(inputBytes: bytes);
  String text = PdfTextExtractor(document).extractText();
  document.dispose();
  extractedText = text;
}
```

3. Handle multi-page PDFs

**App Status After:** App reads PDF files

---

### 🟠 PHASE 18 - Image OCR Support
**Assigned to:** Member 2  
**Difficulty:** ⭐⭐⭐ Challenging  
**Prerequisite:** Phase 17

**What to do:**
1. Add `google_mlkit_text_recognition` package
2. Extract text from images:

```dart
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

if (fileName.endsWith('.jpg') || fileName.endsWith('.png')) {
  final inputImage = InputImage.fromFilePath(path);
  final textRecognizer = TextRecognizer();
  final RecognizedText result = await textRecognizer.processImage(inputImage);
  extractedText = result.text;
  textRecognizer.close();
}
```

**App Status After:** App reads text from images

---

### 🟠 PHASE 19 - Dark Mode
**Assigned to:** Member 3  
**Difficulty:** ⭐⭐⭐ Challenging  
**Prerequisite:** Phase 18

**What to do:**
1. Create light theme
2. Create dark theme
3. Switch based on provider setting:

```dart
MaterialApp(
  theme: ThemeData.light(),
  darkTheme: ThemeData.dark(),
  themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
)
```

**App Status After:** Dark/Light mode toggle works

---

### 🟠 PHASE 20 - Testing & Final Polish
**Assigned to:** Member 4  
**Difficulty:** ⭐⭐⭐ Challenging  
**Prerequisite:** Phase 19

**What to do:**
1. Test all file formats:
   - [ ] .docx files
   - [ ] .pdf files
   - [ ] .txt files
   - [ ] .md files
   - [ ] .jpg/.png images
2. Fix any bugs
3. Add loading indicators
4. Update README with screenshots
5. Build release APK: `flutter build apk`

**App Status After:** Complete, production-ready app!

---

## 📁 Final Folder Structure

```
lib/
├── main.dart
├── screens/
│   ├── home_screen.dart
│   └── settings_screen.dart
├── widgets/
│   └── (optional custom widgets)
├── services/
│   └── (optional service files)
├── models/
│   └── (optional data models)
└── utils/
    └── settings_provider.dart
```

---

## 📦 Final Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # File Selection
  file_picker: ^8.0.0
  
  # Text Extraction
  docx_to_text: ^1.0.1              # Word files
  syncfusion_flutter_pdf: ^24.1.41   # PDF files
  google_mlkit_text_recognition: ^0.11.0  # Image OCR
  
  # Text-to-Speech
  flutter_tts: ^3.8.5
  
  # State & Storage
  provider: ^6.1.1
  shared_preferences: ^2.2.2
```

---

## ✅ File Format Support Summary

| Phase | Format Added | Package |
|-------|--------------|---------|
| Phase 8 | .docx | docx_to_text |
| Phase 12 | .txt, .md | dart:io (built-in) |
| Phase 17 | .pdf | syncfusion_flutter_pdf |
| Phase 18 | .jpg, .png | google_mlkit_text_recognition |

---

## ✅ Checklist for Each Phase

Before marking a phase complete:
- [ ] Code compiles without errors
- [ ] App runs without crashing
- [ ] New feature works as described
- [ ] Previous features still work
- [ ] Code is commented
- [ ] Changes are committed to Git

---

## 🔀 Git Workflow

After completing each phase:
```bash
git add .
git commit -m "Phase X: [Brief description]"
git push
```

---

## 📞 Help Resources

- Flutter Docs: https://docs.flutter.dev/
- Package Docs: https://pub.dev/
- file_picker: https://pub.dev/packages/file_picker
- flutter_tts: https://pub.dev/packages/flutter_tts
- syncfusion_flutter_pdf: https://pub.dev/packages/syncfusion_flutter_pdf
- google_mlkit_text_recognition: https://pub.dev/packages/google_mlkit_text_recognition

---

**Good luck team! 🎉**
