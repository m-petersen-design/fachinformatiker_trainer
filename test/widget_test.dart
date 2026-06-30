import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fachinformatiker_trainer/main.dart';

void main() {
  // Test 1: Überprüft, ob die App überhaupt fehlerfrei startet
  testWidgets('Überprüfung: App initialisiert und baut sich erfolgreich auf', (WidgetTester tester) async {
    themeNotifier.value = ThemeMode.dark;

    await tester.pumpWidget(const FachinformatikerTrainerApp());

    // Wir springen 5 Sekunden vor, damit der 4-Sekunden-Timer im Dashboard komplett durchläuft
    await tester.pump(const Duration(seconds: 5));

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  // Test 2: Überprüft den dynamischen Theme-Wechsel (Jedi Mode vs. Sith Mode)
  testWidgets('Überprüfung: App reagiert korrekt auf Änderungen des globalen Themes', (WidgetTester tester) async {
    themeNotifier.value = ThemeMode.dark;
    await tester.pumpWidget(const FachinformatikerTrainerApp());
    
    // Auch hier dem 4-Sekunden-Timer genug Zeit (5 Sekunden) zum Beenden geben
    await tester.pump(const Duration(seconds: 5));

    MaterialApp app = tester.widget(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);

    // Wechsel auf die helle Seite der Macht
    themeNotifier.value = ThemeMode.light;
    
    // Einen Frame rendern, um die Änderung anzuzeigen
    await tester.pump();

    app = tester.widget(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
  });
}