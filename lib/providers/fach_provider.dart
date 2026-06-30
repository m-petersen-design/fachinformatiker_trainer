import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/fachrichtung.dart';
import '../models/themengebiet.dart';
import '../repositories/fach_repository.dart';

/// **State Management: Provider-Definitionen (Riverpod)**
/// Diese Datei fungiert in unserer Architektur als "Controller" oder "ViewModel".
/// Sie ist das Bindeglied zwischen dem UI (Präsentationsschicht) und der Datenbank (Datenhaltung).
/// Wir nutzen Riverpod, um Daten asynchron zu laden, zu cachen und die UI automatisch 
/// neu zu zeichnen (Reactive Programming), sobald sich Daten ändern.

// --- 1. DEPENDENCY INJECTION (Abhängigkeitsinjektion) ---
/// **fachRepositoryProvider**
/// Ein einfacher Basis-Provider. Anstatt in jedem UI-Screen manuell 'FachRepository()' 
/// zu instanziieren, übergeben wir diese Aufgabe an Riverpod. 
/// Vorteil: Das Repository wird nur einmal im Speicher angelegt (Speichereffizienz) 
/// und kann bei Unit-Tests extrem einfach durch ein Mock-Repository ausgetauscht werden.
final fachRepositoryProvider = Provider((ref) => FachRepository());

// --- 2. ASYNCHRONES DATENLADEN (Reaktiver Zustand) ---
/// **fachrichtungenProvider**
/// Ein 'FutureProvider' ist speziell dafür gemacht, asynchrone Operationen (wie Datenbankabfragen)
/// sicher zu kapseln. Er liefert dem UI nicht nur die reine Liste der Fachrichtungen,
/// sondern automatisch auch den Zustand: Lade ich noch? (loading), Gab es einen Fehler? (error) 
/// oder Sind die Daten da? (data).
final fachrichtungenProvider = FutureProvider<List<Fachrichtung>>((ref) async {
  // Wir "lesen" (read) unseren injizierten Repository-Provider aus...
  final repo = ref.read(fachRepositoryProvider);
  // ... und rufen die asynchrone Datenbank-Methode auf.
  return repo.getFachrichtungen();
});

// --- 3. PARAMETRISIERTE PROVIDER ---
/// **themengebieteProvider**
/// Der '.family'-Modifier in Riverpod ist ein mächtiges Werkzeug. Er erlaubt es uns, 
/// Argumente (hier: die fachrichtungId) an einen Provider zu übergeben, wenn wir ihn aufrufen.
/// 
/// Architektur-Hinweis (Typensicherheit): 
/// Im Vergleich zu früheren Versionen wurde der Parameter-Typ strikt von String auf 'int' 
/// korrigiert. Da SQLite Primary/Foreign Keys als Integer verarbeitet, garantiert diese 
/// Typisierung, dass wir keine SQL-Casts durchführen müssen und Type-Mismatch-Fehler 
/// schon zur Kompilierzeit abgefangen werden.
final themengebieteProvider = FutureProvider.family<List<Themengebiet>, int>((ref, fachrichtungId) async {
  final repo = ref.read(fachRepositoryProvider);
  // Wir holen gezielt nur die Themengebiete (z.B. Netzwerktechnik), 
  // die zum übergebenen Fremdschlüssel (z.B. 1 für FISI) gehören.
  return repo.getThemengebiete(fachrichtungId);
});