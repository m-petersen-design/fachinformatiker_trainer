import 'package:audioplayers/audioplayers.dart';

class AudioService {
  // Singleton-Muster, damit der Service überall verfügbar ist
  static final AudioService instance = AudioService._internal();
  AudioService._internal();

  final AudioPlayer _uiPlayer = AudioPlayer();
  final AudioPlayer _fxPlayer = AudioPlayer();

  Future<void> playClick() async {
    try {
      await _uiPlayer.play(AssetSource('sounds/click.mp3'));
    } catch (e) {
      // Ignoriere, falls die MP3 fehlt
    }
  }

  Future<void> playSuccess() async {
    try {
      await _fxPlayer.play(AssetSource('sounds/success.mp3'));
    } catch (e) {}
  }

  Future<void> playError() async {
    try {
      await _fxPlayer.play(AssetSource('sounds/error.mp3'));
    } catch (e) {}
  }

  Future<void> playStartup() async {
    try {
      await _fxPlayer.play(AssetSource('sounds/startup.mp3'));
    } catch (e) {}
  }
}