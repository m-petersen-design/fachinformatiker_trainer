import 'package:audioplayers/audioplayers.dart';

/// **AudioService (Singleton)**
/// Diese Klasse ist nach dem Single Responsibility Principle (SRP) aufgebaut.
/// Ihre einzige Aufgabe ist das Routen und Abspielen von lokalen Audio-Assets.
/// Die Benutzeroberfläche (UI) muss nicht wissen, wie MP3s geladen werden, 
/// sie ruft lediglich z.B. [AudioService.instance.playClick()] auf.
class AudioService {
  
  // --- SINGLETON PATTERN ---
  // Die statische Konstante 'instance' speichert die einzige Instanz dieser Klasse.
  static final AudioService instance = AudioService._internal();
  
  // Ein benannter, privater Konstruktor (erkennbar am Unterstrich).
  // Verhindert, dass andere Klassen versehentlich 'new AudioService()' aufrufen 
  // und somit mehrere, unkontrollierte Audio-Instanzen im RAM erzeugen.
  AudioService._internal();

  // --- AUDIO KANÄLE (Concurrency) ---
  // Wir nutzen BEWUSST zwei separate AudioPlayer-Instanzen.
  // Grund: Wenn der User schnell auf "Nächste Frage" klickt, während der 
  // Erfolgs-Sound (Success) noch läuft, würde ein einziger Player den Erfolgssound 
  // sofort abbrechen, um den Klick-Sound zu spielen. Zwei Kanäle verhindern das.
  
  // Player 1: Reserviert für extrem kurze, schnelle UI-Interaktionen (Klicks)
  final AudioPlayer _uiPlayer = AudioPlayer();
  
  // Player 2: Reserviert für längere Effekte (FX) wie Jingles, Vader-Sounds oder den App-Start
  final AudioPlayer _fxPlayer = AudioPlayer();

  /// **Spielt einen kurzen UI-Klick-Sound ab**
  /// Nutzt den [_uiPlayer], damit laufende [_fxPlayer]-Sounds nicht unterbrochen werden.
  Future<void> playClick() async {
    try {
      await _uiPlayer.play(AssetSource('sounds/click.mp3'));
    } catch (e) {
      // Defensive Programmierung: Ein leerer Catch-Block.
      // Falls auf einem Ziel-PC die Soundkarte fehlt oder die MP3 gelöscht wurde,
      // stürzt die App nicht mit einem fatalen Fehler ab, sondern bleibt einfach stumm.
    }
  }

  /// **Spielt den Erfolgs-Sound ab (z.B. bei richtiger Antwort)**
  Future<void> playSuccess() async {
    try {
      await _fxPlayer.play(AssetSource('sounds/success.mp3'));
    } catch (e) {}
  }

  /// **Spielt den Fehler-Sound ab (z.B. bei falscher Antwort)**
  Future<void> playError() async {
    try {
      await _fxPlayer.play(AssetSource('sounds/error.mp3'));
    } catch (e) {}
  }

  /// **Spielt den Begrüßungs-Sound beim Start der Anwendung**
  Future<void> playStartup() async {
    try {
      await _fxPlayer.play(AssetSource('sounds/startup.mp3'));
    } catch (e) {}
  }
}