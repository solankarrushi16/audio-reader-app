# 🎧 Audio Reader App

A simple Text-to-Speech app for reading documents aloud. Built with Flutter.

## 📱 Features
- **Multiple File Formats Support:**
  - Word documents (.docx)
  - PDF files (.pdf)
  - Text files (.txt)
  - Markdown files (.md)
  - Images with text (OCR)
- Extract text from documents
- Read text aloud using Text-to-Speech
- Play, Pause, Stop controls
- Adjustable speech rate and pitch
- Dark mode support
- Settings persistence

## 👥 Team Members

| Member | Phases Assigned |
|--------|-----------------|
| Member 1 | 1, 5, 9, 13, 17 |
| Member 2 | 2, 6, 10, 14, 18 |
| Member 3 | 3, 7, 11, 15, 19 |
| Member 4 | 4, 8, 12, 16, 20 |

## 📋 Documentation

See [docs/TEAM_DEVELOPMENT_PLAN.md](docs/TEAM_DEVELOPMENT_PLAN.md) for complete 20-phase development plan with detailed instructions for each phase.

## 🚀 How to Run

```bash
# Navigate to project folder
cd audio_reader_app

# Get dependencies
flutter pub get

# Run the app
flutter run
```

## 📦 Dependencies

| Package | Purpose |
|---------|---------|
| file_picker | Select files from device |
| docx_to_text | Extract text from Word docs |
| syncfusion_flutter_pdf | Extract text from PDF files |
| google_ml_kit | OCR - Extract text from images |
| flutter_tts | Text-to-Speech functionality |
| provider | State management |
| shared_preferences | Local storage |

## 📁 Project Structure

```
lib/
├── main.dart
├── screens/
│   ├── home_screen.dart
│   └── settings_screen.dart
├── widgets/
│   ├── file_info_card.dart
│   └── audio_control_button.dart
└── utils/
    └── settings_provider.dart
```

## 🔀 Git Workflow

```bash
git add .
git commit -m "Phase X: Description"
git push
```
