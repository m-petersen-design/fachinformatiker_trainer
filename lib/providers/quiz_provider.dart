import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/quiz_repository.dart';
import '../models/frage.dart';
import '../models/antwort_option.dart';

/// **State Management: Quiz Data Providers**
/// Diese Datei definiert die globalen Schnittstellen (Provider), über die 
/// unsere UI-Screens asynchron Daten aus der Datenbank anfordern können.
/// Durch diese Architektur weiß das Frontend absolut nichts über SQLite oder SQL-Queries.

// --- DEPENDENCY INJECTION ---
/// **quizRepositoryProvider**
/// Stellt eine globale, zustandslose Instanz unseres QuizRepositories zur Verfügung.
/// Anstatt in jedem FutureProvider 'QuizRepository()' neu zu instanziieren,
/// greifen alle auf diesen einen Provider zu. Das schont den Arbeitsspeicher 
/// und macht das System extrem testbar (für Unit-Tests kann hier einfach ein Mock eingehängt werden).
final quizRepositoryProvider = Provider((ref) => QuizRepository());

// --- ASYNCHRONE DATEN-STREAMS MIT PARAMETERN ---
/// **fragenProvider**
/// Ein parametrisierter Provider (erkennbar am '.family'-Modifier).
/// Er erwartet eine 'themengebietId' (int) und liefert asynchron eine Liste von Fragen zurück.
final fragenProvider = FutureProvider.family<List<Frage>, int>((ref, themengebietId) async {
  
  // --- DAS REAKTIVITÄTS-GEHEIMNIS: watch vs. read ---
  // Wir nutzen hier ref.watch() anstelle von ref.read().
  // Warum? ref.watch() baut eine reaktive Abhängigkeit ("Subscription") auf.
  // Würde sich der 'quizRepositoryProvider' jemals ändern (z.B. weil der Nutzer sich einloggt 
  // und ein neues User-Token für das Repo generiert wird), merkt dieser fragenProvider das 
  // sofort automatisch und lädt die Fragen von selbst neu. 
  // ref.read() würde das Repo nur ein einziges Mal stumpf auslesen und bei Änderungen kaputtgehen.
  final repo = ref.watch(quizRepositoryProvider); 
  
  // Ruft die asynchrone DB-Methode auf. Riverpod kümmert sich automatisch darum,
  // der UI während der Wartezeit einen "Loading"-State (z.B. Ladekreis) zu senden.
  return repo.getFragenFuerThema(themengebietId);
});

/// **antwortenProvider**
/// Ein weiterer parametrisierter Provider. Er nimmt die 'frageId' einer spezifischen Frage 
/// und lädt genau die 4 dazugehörigen Multiple-Choice-Antworten aus der Datenbank.
final antwortenProvider = FutureProvider.family<List<AntwortOption>, int>((ref, frageId) async {
  
  // Auch hier: Strikte Anwendung von ref.watch() für reaktive Abhängigkeiten 
  // innerhalb des Provider-Baums (Best Practice der Riverpod-Dokumentation).
  final repo = ref.watch(quizRepositoryProvider); 
  
  return repo.getAntwortenFuerFrage(frageId);
});