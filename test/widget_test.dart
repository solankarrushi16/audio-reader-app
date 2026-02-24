// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';

import 'package:audio_reader_app/main.dart';

void main() {
  testWidgets('App shows Audio Reader title', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AudioReaderApp());

    // Verify that our app title is shown.
    expect(find.text('Audio Reader'), findsOneWidget);
    expect(find.text('Hello Audio Reader!'), findsOneWidget);
  });
}
