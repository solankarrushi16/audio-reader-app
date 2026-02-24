# 🎧 Audio Reader App - Team Development Plan

## 📋 Project Information
- **App Name:** Audio Reader
- **Purpose:** Text-to-Speech app for reading documents aloud
- **Team Size:** 4 Members
- **Total Phases:** 20 (5 phases per member)
- **Complexity Level:** Simple (No complex state management)

---

## 👥 Team Member Distribution

| Member | Phases Assigned | Focus Area |
|--------|-----------------|------------|
| **Member 1** | 1, 5, 9, 13, 17 | Structure, State, TTS Core, Navigation, File Formats |
| **Member 2** | 2, 6, 10, 14, 18 | App Shell, Buttons, Audio Controls, Settings UI, TTS Settings |
| **Member 3** | 3, 7, 11, 15, 19 | Text Widget, File Picker, Styling, Provider, Dark Mode |
| **Member 4** | 4, 8, 12, 16, 20 | Layouts, Text Extract, Custom Widgets, Storage, Testing |

---

## 📊 Difficulty Balance

Each member gets: **2 Easy + 2 Medium + 1 Slightly Challenging**

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
   - `lib/screens/` - for screen files
   - `lib/widgets/` - for reusable widgets
   - `lib/services/` - for TTS, file services
   - `lib/models/` - for data classes
   - `lib/utils/` - for helper functions

2. Clean `main.dart` to minimal code:
```dart
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
```

**App Status After:** App runs with "Hello Audio Reader" text

---

### 🟢 PHASE 2 - Basic App Shell
**Assigned to:** Member 2  
**Difficulty:** ⭐ Easy  
**Prerequisite:** Phase 1

**What to do:**
1. Create proper MaterialApp setup
2. Remove debug banner (`debugShowCheckedModeBanner: false`)
3. Add AppBar with centered title
4. Create separate HomePage widget class

```dart
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
      appBar: AppBar(
        title: const Text('Audio Reader'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'Welcome to Audio Reader',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
```

**App Status After:** App shows AppBar and welcome text

---

### 🟢 PHASE 3 - Basic Widgets (Text & Container)
**Assigned to:** Member 3  
**Difficulty:** ⭐ Easy  
**Prerequisite:** Phase 2

**What to do:**
1. Add multiple Text widgets with different styles
2. Use Container to wrap content
3. Add Column to arrange texts vertically

**Update HomePage body:**
```dart
body: Center(
  child: Container(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Upload a Document',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Select a Word document to read aloud',
          style: TextStyle(fontSize: 16),
        ),
        const Text(
          'No file selected',
          style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
        ),
      ],
    ),
  ),
),
```

**App Status After:** App shows three text lines

---

### 🟢 PHASE 4 - Layout Widgets (Row & Column)
**Assigned to:** Member 4  
**Difficulty:** ⭐ Easy  
**Prerequisite:** Phase 3

**What to do:**
1. Add Padding around content
2. Add SizedBox for spacing
3. Add Container with border for file info
4. Add Row for button placeholders at bottom

**Concepts:** `Padding`, `SizedBox`, `Column`, `Row`, `BoxDecoration`

**App Status After:** Properly spaced layout with placeholders

---

### 🟢 PHASE 5 - Stateful Widget Conversion
**Assigned to:** Member 1  
**Difficulty:** ⭐ Easy  
**Prerequisite:** Phase 4

**What to do:**
1. Create `lib/screens/home_screen.dart`
2. Move HomePage to this file
3. Convert to StatefulWidget
4. Add state variables:
   - `String selectedFileName = 'No file selected';`
   - `String extractedText = '';`
5. Update main.dart to import home_screen.dart

**Concepts:** `StatefulWidget`, `State`, state variables, file imports

**App Status After:** Same UI but with organized code structure

---

### 🟢 PHASE 6 - Button Widgets
**Assigned to:** Member 2  
**Difficulty:** ⭐ Easy  
**Prerequisite:** Phase 5

**What to do:**
1. Add ElevatedButton for "Select File"
2. Add FloatingActionButton for Play/Stop
3. Add `isPlaying` state variable
4. Implement onPressed with setState

```dart
ElevatedButton.icon(
  onPressed: () {
    setState(() {
      selectedFileName = 'sample.docx';
      extractedText = 'Sample text for testing...';
    });
  },
  icon: const Icon(Icons.upload_file),
  label: const Text('Select Word File'),
),
```

**Concepts:** `ElevatedButton`, `FloatingActionButton`, `onPressed`, `setState`

**App Status After:** Clicking button updates text on screen

---

### 🟢 PHASE 7 - File Picker Integration
**Assigned to:** Member 3  
**Difficulty:** ⭐⭐ Easy-Medium  
**Prerequisite:** Phase 6

**What to do:**
1. Add to pubspec.yaml:
   ```yaml
   dependencies:
     file_picker: ^8.0.0
   ```
2. Run `flutter pub get`
3. Implement file picking:

```dart
import 'package:file_picker/file_picker.dart';

Future<void> pickFile() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['docx'],
  );
  
  if (result != null) {
    setState(() {
      selectedFileName = result.files.first.name;
    });
  }
}
```

**Concepts:** Packages, pubspec.yaml, async/await, Future

**App Status After:** User can select .docx file and see filename

---

### 🟡 PHASE 8 - Text Extraction from DOCX
**Assigned to:** Member 4  
**Difficulty:** ⭐⭐ Medium  
**Prerequisite:** Phase 7

**What to do:**
1. Add to pubspec.yaml:
   ```yaml
   dependencies:
     docx_to_text: ^1.0.1
   ```
2. Extract text from selected file:

```dart
import 'dart:io';
import 'package:docx_to_text/docx_to_text.dart';

// Inside pickFile function, after getting result:
if (result != null && result.files.first.path != null) {
  File file = File(result.files.first.path!);
  final bytes = await file.readAsBytes();
  String text = docxToText(bytes);
  
  setState(() {
    selectedFileName = result.files.first.name;
    extractedText = text;
  });
}
```

**Concepts:** File reading, bytes, docx parsing

**App Status After:** Selected document text is displayed

---

### 🟡 PHASE 9 - Basic Text-to-Speech
**Assigned to:** Member 1  
**Difficulty:** ⭐⭐ Medium  
**Prerequisite:** Phase 8

**What to do:**
1. Add to pubspec.yaml:
   ```yaml
   dependencies:
     flutter_tts: ^3.8.5
   ```
2. Initialize TTS and implement speak:

```dart
import 'package:flutter_tts/flutter_tts.dart';

// In state class:
final FlutterTts flutterTts = FlutterTts();

@override
void initState() {
  super.initState();
  flutterTts.setLanguage("en-US");
  flutterTts.setSpeechRate(0.5);
}

Future<void> speak() async {
  if (extractedText.isNotEmpty) {
    await flutterTts.speak(extractedText);
  }
}
```

**Concepts:** FlutterTts, initState, speak()

**App Status After:** App reads text aloud when button pressed

---

### 🟡 PHASE 10 - Audio Controls (Play/Pause/Stop)
**Assigned to:** Member 2  
**Difficulty:** ⭐⭐ Medium  
**Prerequisite:** Phase 9

**What to do:**
1. Add play/pause toggle:
```dart
Future<void> togglePlayPause() async {
  if (isPlaying) {
    await flutterTts.pause();
    setState(() => isPlaying = false);
  } else {
    await flutterTts.speak(extractedText);
    setState(() => isPlaying = true);
  }
}

Future<void> stop() async {
  await flutterTts.stop();
  setState(() => isPlaying = false);
}
```

2. Update button icons based on state

**Concepts:** pause(), stop(), state toggling

**App Status After:** Working Play, Pause, Stop buttons

---

### 🟡 PHASE 11 - Basic Styling
**Assigned to:** Member 3  
**Difficulty:** ⭐⭐ Medium  
**Prerequisite:** Phase 10

**What to do:**
1. Add theme in MaterialApp:
```dart
theme: ThemeData(
  primarySwatch: Colors.blue,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.blue,
    foregroundColor: Colors.white,
  ),
),
```

2. Style containers with colors and borders
3. Add proper padding and margins

**Concepts:** ThemeData, Colors, BoxDecoration

**App Status After:** App looks visually appealing

---

### 🟡 PHASE 12 - Custom Widgets
**Assigned to:** Member 4  
**Difficulty:** ⭐⭐ Medium  
**Prerequisite:** Phase 11

**What to do:**
1. Create `lib/widgets/file_info_card.dart`:
```dart
class FileInfoCard extends StatelessWidget {
  final String fileName;
  
  const FileInfoCard({super.key, required this.fileName});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      // Card UI here
    );
  }
}
```

2. Create `lib/widgets/audio_control_button.dart`
3. Use these widgets in home_screen.dart

**Concepts:** Custom widgets, constructor parameters

**App Status After:** Same functionality with cleaner code

---

### 🟡 PHASE 13 - Navigation (Settings Screen)
**Assigned to:** Member 1  
**Difficulty:** ⭐⭐ Medium  
**Prerequisite:** Phase 12

**What to do:**
1. Create `lib/screens/settings_screen.dart` (empty scaffold)
2. Add settings icon in AppBar
3. Implement navigation:

```dart
// In AppBar actions:
IconButton(
  icon: const Icon(Icons.settings),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  },
),
```

**Concepts:** Navigator.push, MaterialPageRoute

**App Status After:** Can navigate to Settings and back

---

### 🟡 PHASE 14 - Settings Screen UI
**Assigned to:** Member 2  
**Difficulty:** ⭐⭐ Medium  
**Prerequisite:** Phase 13

**What to do:**
1. Add Slider for speech rate
2. Add Switch for dark mode toggle
3. Layout with ListTile:

```dart
ListTile(
  title: const Text('Speech Rate'),
  subtitle: Slider(
    value: speechRate,
    min: 0.25,
    max: 1.5,
    onChanged: (value) {
      setState(() => speechRate = value);
    },
  ),
),
```

**Concepts:** Slider, Switch, ListTile

**App Status After:** Settings screen with controls

---

### 🟡 PHASE 15 - Simple State Sharing (Provider)
**Assigned to:** Member 3  
**Difficulty:** ⭐⭐⭐ Medium-Challenging  
**Prerequisite:** Phase 14

**What to do:**
1. Add to pubspec.yaml:
   ```yaml
   dependencies:
     provider: ^6.1.1
   ```
2. Create `lib/utils/settings_provider.dart`:
```dart
import 'package:flutter/material.dart';

class SettingsProvider extends ChangeNotifier {
  double _speechRate = 0.5;
  bool _isDarkMode = false;
  
  double get speechRate => _speechRate;
  bool get isDarkMode => _isDarkMode;
  
  void setSpeechRate(double rate) {
    _speechRate = rate;
    notifyListeners();
  }
  
  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
}
```

3. Wrap app with ChangeNotifierProvider in main.dart

**Concepts:** Provider, ChangeNotifier, notifyListeners

**App Status After:** Settings changes reflect across app

---

### 🟡 PHASE 16 - Local Storage
**Assigned to:** Member 4  
**Difficulty:** ⭐⭐⭐ Medium-Challenging  
**Prerequisite:** Phase 15

**What to do:**
1. Add to pubspec.yaml:
   ```yaml
   dependencies:
     shared_preferences: ^2.2.2
   ```
2. Save and load settings:
```dart
import 'package:shared_preferences/shared_preferences.dart';

Future<void> saveSettings() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble('speechRate', _speechRate);
  await prefs.setBool('isDarkMode', _isDarkMode);
}

Future<void> loadSettings() async {
  final prefs = await SharedPreferences.getInstance();
  _speechRate = prefs.getDouble('speechRate') ?? 0.5;
  _isDarkMode = prefs.getBool('isDarkMode') ?? false;
  notifyListeners();
}
```

**Concepts:** SharedPreferences, async storage

**App Status After:** Settings persist after app restart

---

### 🟠 PHASE 17 - Multiple File Formats
**Assigned to:** Member 1  
**Difficulty:** ⭐⭐⭐ Challenging  
**Prerequisite:** Phase 16

**What to do:**
1. Support .txt files:
```dart
allowedExtensions: ['docx', 'txt'],

// In file processing:
if (fileName.endsWith('.txt')) {
  extractedText = await File(path).readAsString();
} else if (fileName.endsWith('.docx')) {
  // existing docx code
}
```

2. Show appropriate messages for unsupported files

**Concepts:** File extensions, conditional logic

**App Status After:** App reads both .docx and .txt files

---

### 🟠 PHASE 18 - TTS Settings Integration
**Assigned to:** Member 2  
**Difficulty:** ⭐⭐⭐ Challenging  
**Prerequisite:** Phase 17

**What to do:**
1. Apply speech rate from provider to TTS
2. Add pitch control in settings
3. Listen to provider changes:

```dart
final settings = Provider.of<SettingsProvider>(context);
flutterTts.setSpeechRate(settings.speechRate);
```

**Concepts:** Provider integration with TTS

**App Status After:** TTS uses settings from Settings screen

---

### 🟠 PHASE 19 - Dark Mode Implementation
**Assigned to:** Member 3  
**Difficulty:** ⭐⭐⭐ Challenging  
**Prerequisite:** Phase 18

**What to do:**
1. Create light and dark themes
2. Switch based on provider:

```dart
MaterialApp(
  theme: ThemeData.light(),
  darkTheme: ThemeData.dark(),
  themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
)
```

**Concepts:** ThemeData, ThemeMode, dynamic theming

**App Status After:** App has working dark/light mode toggle

---

### 🟠 PHASE 20 - Final Testing & Polish
**Assigned to:** Member 4  
**Difficulty:** ⭐⭐⭐ Challenging  
**Prerequisite:** Phase 19

**What to do:**
1. Test all features work together
2. Fix any bugs
3. Add loading indicators
4. Update README.md
5. Build release APK: `flutter build apk`

**Concepts:** Testing, debugging, APK build

**App Status After:** Complete, polished, production-ready app!

---

## 📁 Final Folder Structure

```
lib/
├── main.dart
├── screens/
│   ├── home_screen.dart
│   └── settings_screen.dart
├── widgets/
│   ├── file_info_card.dart
│   └── audio_control_button.dart
├── services/
│   └── (empty - kept simple)
├── models/
│   └── (empty - kept simple)
└── utils/
    └── settings_provider.dart
```

---

## 📦 Final Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  file_picker: ^8.0.0        # Phase 7
  docx_to_text: ^1.0.1       # Phase 8
  flutter_tts: ^3.8.5        # Phase 9
  provider: ^6.1.1           # Phase 15
  shared_preferences: ^2.2.2  # Phase 16
```

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
- Dart Docs: https://dart.dev/guides
- Package Docs: https://pub.dev/

---

**Good luck team! 🎉**
