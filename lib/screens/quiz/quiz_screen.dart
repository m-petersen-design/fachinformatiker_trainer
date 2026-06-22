import 'package:flutter/material.dart';
import '../../core/database/database_service.dart';
import 'package:sqflite/sqflite.dart'; // Wichtig für ConflictAlgorithm

class QuizScreen extends StatefulWidget {
  final int themengebietId;
  final String themengebietName;

  const QuizScreen({
    super.key, 
    required this.themengebietId,
    required this.themengebietName,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _quizDaten = [];
  
  int _aktuelleFrageIndex = 0;
  bool _quizBeendet = false;

  // State für Live-Statistiken & XP
  int _richtigeAntworten = 0;
  int _falscheAntworten = 0;
  int _aktuelleXP = 0;

  bool _frageBeantwortet = false;
  int? _gewaehlteAntwortIndex; 
  final _freitextController = TextEditingController();

  // ==========================================
  // VADER AVATAR STATE
  // ==========================================
  int _aktuelleStreak = 0;
  bool _zeigeVader = false;
  String _vaderSpruch = '';
  String _vaderGifPath = 'assets/vader_lob.gif'; // Fallback

  final List<String> _vaderLob = [
    "Die Macht ist stark in dir!",
    "Beeindruckend. Höchst beeindruckend.",
    "Du hast dein Schicksal akzeptiert.",
    "Die IT-Macht gehorcht dir gut."
  ];

  final List<String> _vaderKritik = [
    "Ich finde deinen Mangel an Wissen beklagenswert.",
    "Du hast mich zum letzten Mal enttäuscht.",
    "Unterschätze niemals die Komplexität der Systeme.",
    "Noch bist du kein Jedi-Meister."
  ];

  @override
  void initState() {
    super.initState();
    _ladeGemischtesQuiz();
  }

  @override
  void dispose() {
    _freitextController.dispose();
    super.dispose();
  }

  Future<void> _ladeGemischtesQuiz() async {
    final db = await DatabaseService.instance.database;
    final rawFragen = await db.query('frage', where: 'themengebiet_id = ?', whereArgs: [widget.themengebietId]);
    List<Map<String, dynamic>> spielbareFragen = rawFragen.map((e) => Map<String, dynamic>.from(e)).toList();
    spielbareFragen.shuffle(); 

    List<Map<String, dynamic>> komplettesQuiz = [];

    for (var frage in spielbareFragen) {
      if (frage['typ'] == 'freitext') {
        komplettesQuiz.add({'frage': frage, 'antworten': []});
        continue;
      }
      final rawAntworten = await db.query('antwort_option', where: 'frage_id = ?', whereArgs: [frage['id']]);
      List<Map<String, dynamic>> gemischteAntworten = rawAntworten.map((e) => Map<String, dynamic>.from(e)).toList();
      gemischteAntworten.shuffle(); 

      komplettesQuiz.add({'frage': frage, 'antworten': gemischteAntworten});
    }

    setState(() {
      _quizDaten = komplettesQuiz;
      _isLoading = false;
    });
  }

  // ==========================================
  // AVATAR LOGIK
  // ==========================================
  void _pruefeAvatarEinsatz(bool warRichtig) {
    if (warRichtig) {
      _aktuelleStreak++;
      // Lob bei jeder 3. richtigen Antwort in Folge
      if (_aktuelleStreak > 0 && _aktuelleStreak % 3 == 0) {
        _triggerVaderOverlay(true);
      }
    } else {
      _aktuelleStreak = 0; // Streak gebrochen!
      // Vader meckert bei einem Fehler
      _triggerVaderOverlay(false);
    }
  }

  void _triggerVaderOverlay(bool lob) {
    setState(() {
      _vaderSpruch = lob ? (_vaderLob..shuffle()).first : (_vaderKritik..shuffle()).first;
      _vaderGifPath = lob ? 'assets/vader_lob.gif' : 'assets/vader_kritik.gif';
      _zeigeVader = true;
    });

    // Nach 4 Sekunden verschwindet er wieder
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _zeigeVader = false;
        });
      }
    });
  }

  // ==========================================
  // NEU: SPACED REPETITION ALGORITHMUS
  // ==========================================
  Future<void> _frageFortschrittSpeichern(int frageId, bool warRichtig) async {
    final db = await DatabaseService.instance.database;
    final String jetzt = DateTime.now().toIso8601String();

    // Bisherigen Fortschritt dieser spezifischen Frage abrufen
    final List<Map<String, dynamic>> result = await db.query(
      'user_fortschritt',
      where: 'frage_id = ?',
      whereArgs: [frageId],
    );

    int altesIntervall = 0;
    int versuche = 0;

    if (result.isNotEmpty) {
      altesIntervall = result.first['intervall_tage'] as int;
      versuche = result.first['anzahl_versuche'] as int;
    }

    int neuesIntervall;
    if (warRichtig) {
      // Wenn richtig: Intervall wächst (1, 2, 4, 8 Tage...)
      neuesIntervall = altesIntervall == 0 ? 1 : altesIntervall * 2;
    } else {
      // Wenn falsch: Intervall zurück auf 0 (Muss bald wiederholt werden!)
      neuesIntervall = 0;
    }

    // Wann ist die Frage das nächste Mal dran?
    final naechsteFaelligkeit = DateTime.now().add(Duration(days: neuesIntervall)).toIso8601String();

    // In die Datenbank schreiben
    await db.insert(
      'user_fortschritt',
      {
        'frage_id': frageId,
        'korrekt_beantwortet': warRichtig ? 1 : 0,
        'anzahl_versuche': versuche + 1,
        'letzter_versuch': jetzt,
        'naechste_faelligkeit': naechsteFaelligkeit,
        'intervall_tage': neuesIntervall,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ==========================================
  // ANTWORTEN AUSWERTEN
  // ==========================================
  void _mcAntwortAuswerten(int index, dynamic istKorrektRaw) {
    if (_frageBeantwortet) return; 

    setState(() {
      _gewaehlteAntwortIndex = index;
      _frageBeantwortet = true;

      int istKorrekt = (istKorrektRaw is int) ? istKorrektRaw : int.tryParse(istKorrektRaw.toString()) ?? 0;
      bool warRichtig = (istKorrekt == 1);

      if (warRichtig) {
        _richtigeAntworten++;
        _aktuelleXP += 10; 
      } else {
        _falscheAntworten++;
      }
      
      _pruefeAvatarEinsatz(warRichtig);
    });

    // NEU: Fortschritt speichern
    final frageId = _quizDaten[_aktuelleFrageIndex]['frage']['id'] as int;
    _frageFortschrittSpeichern(frageId, _gewaehlteAntwortIndex != null && istKorrektRaw.toString() == "1");
  }

  void _freitextMusterloesungAnzeigen() {
    if (_freitextController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte gib eine Antwort ein!'), backgroundColor: Colors.orange));
      return;
    }
    setState(() {
      _frageBeantwortet = true;
    });
  }

  void _freitextSelbstbewertung(bool warRichtig) {
    setState(() {
      if (warRichtig) {
        _richtigeAntworten++;
        _aktuelleXP += 15; 
      } else {
        _falscheAntworten++;
      }
      _pruefeAvatarEinsatz(warRichtig);
    });

    // NEU: Fortschritt speichern
    final frageId = _quizDaten[_aktuelleFrageIndex]['frage']['id'] as int;
    _frageFortschrittSpeichern(frageId, warRichtig);

    _naechsteFrage();
  }

  Future<void> _xpInDatenbankSpeichern() async {
    if (_aktuelleXP > 0) {
      final db = await DatabaseService.instance.database;
      await db.rawUpdate(
        'UPDATE fachrichtung SET xp = xp + ? WHERE id = (SELECT fachrichtung_id FROM themengebiet WHERE id = ?)', 
        [_aktuelleXP, widget.themengebietId]
      );
    }
  }

  void _naechsteFrage() {
    if (_aktuelleFrageIndex < _quizDaten.length - 1) {
      setState(() {
        _aktuelleFrageIndex++;
        _frageBeantwortet = false;
        _gewaehlteAntwortIndex = null;
        _freitextController.clear();
      });
    } else {
      setState(() {
        _quizBeendet = true;
      });
      _xpInDatenbankSpeichern();
    }
  }

  Widget _buildLiveStatsHUD() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.blueGrey[800],
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.check_circle, Colors.greenAccent, '$_richtigeAntworten'),
          _buildStatItem(Icons.cancel, Colors.redAccent, '$_falscheAntworten'),
          _buildStatItem(Icons.local_fire_department, Colors.orangeAccent, '$_aktuelleStreak'),
          Container(width: 1, height: 30, color: Colors.blueGrey[600]), 
          _buildStatItem(Icons.star, Colors.amber, '$_aktuelleXP XP'),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(appBar: AppBar(title: Text(widget.themengebietName)), body: const Center(child: CircularProgressIndicator()));
    if (_quizDaten.isEmpty) return Scaffold(appBar: AppBar(title: Text(widget.themengebietName)), body: const Center(child: Text('Keine Fragen vorhanden.')));
    if (_quizBeendet) return _buildErgebnisScreen();

    final aktuelleDaten = _quizDaten[_aktuelleFrageIndex];
    final frage = aktuelleDaten['frage'] as Map<String, dynamic>;
    
    // HARD FIX FOR BUILD: Sicheres Auslesen der Antworten
    List<Map<String, dynamic>> antworten = [];
    if (aktuelleDaten['antworten'] != null) {
      antworten = List<dynamic>.from(aktuelleDaten['antworten'])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.themengebietName), backgroundColor: Colors.blueGrey[900], foregroundColor: Colors.white),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLiveStatsHUD(),

                Text('Frage ${_aktuelleFrageIndex + 1} von ${_quizDaten.length}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 16),

                if (frage['bild_pfad'] != null && frage['bild_pfad'].toString().isNotEmpty) ...[
                  Container(height: 150, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: const Center(child: Text('🖼️ Bild'))),
                  const SizedBox(height: 20),
                ],

                Text(frage['frage_text'].toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 30),

                if (frage['typ'] == 'multiple_choice') ...[
                  ...antworten.asMap().entries.map((entry) {
                    int index = entry.key;
                    var antwort = entry.value;
                    int istKorrekt = (antwort['ist_korrekt'] is int) ? antwort['ist_korrekt'] : int.tryParse(antwort['ist_korrekt'].toString()) ?? 0;

                    Color buttonColor = Colors.white;
                    Color textColor = Colors.black87;

                    if (_frageBeantwortet) {
                      if (istKorrekt == 1) {
                        buttonColor = Colors.green; 
                        textColor = Colors.white;
                      } else if (_gewaehlteAntwortIndex == index) {
                        buttonColor = Colors.red; 
                        textColor = Colors.white;
                      } else {
                        buttonColor = Colors.grey[200]!; 
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                          foregroundColor: textColor,
                          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                          alignment: Alignment.centerLeft,
                          side: const BorderSide(color: Colors.grey, width: 0.5),
                        ),
                        onPressed: () => _mcAntwortAuswerten(index, antwort['ist_korrekt']),
                        child: Text(antwort['text'].toString(), style: const TextStyle(fontSize: 16)),
                      ),
                    );
                  }),

                  if (_frageBeantwortet) ...[
                    const SizedBox(height: 20),
                    if (frage['erklaerung'] != null && frage['erklaerung'].toString().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.blue[50],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('💡 Erklärung:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                            const SizedBox(height: 8),
                            Text(frage['erklaerung'].toString()),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blueGrey[900], foregroundColor: Colors.white),
                      onPressed: _naechsteFrage,
                      child: const Text('Nächste Frage ➔', style: TextStyle(fontSize: 18)),
                    )
                  ]
                ] else ...[
                  TextField(
                    controller: _freitextController,
                    maxLines: 5,
                    enabled: !_frageBeantwortet,
                    decoration: const InputDecoration(
                      labelText: 'Deine Antwort',
                      border: OutlineInputBorder(),
                      hintText: 'Tippe hier deine ausführliche Antwort ein...',
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  if (!_frageBeantwortet)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blue, foregroundColor: Colors.white),
                      onPressed: _freitextMusterloesungAnzeigen,
                      icon: const Icon(Icons.check),
                      label: const Text('Antwort einloggen & Musterlösung prüfen', style: TextStyle(fontSize: 16)),
                    )
                  else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.green[50], border: Border.all(color: Colors.green)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('✅ Musterlösung:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 18)),
                          const SizedBox(height: 8),
                          Text(frage['erklaerung']?.toString() ?? 'Keine Musterlösung hinterlegt.', style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text('War deine Antwort sinngemäß richtig?', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[100], foregroundColor: Colors.red[900], padding: const EdgeInsets.symmetric(vertical: 16)),
                            onPressed: () => _freitextSelbstbewertung(false),
                            child: const Text('❌ Nein (Falsch)'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                            onPressed: () => _freitextSelbstbewertung(true),
                            child: const Text('✅ Ja (+15 XP)'),
                          ),
                        ),
                      ],
                    )
                  ]
                ],
              ],
            ),
          ),
          
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            bottom: _zeigeVader ? 20 : -300, 
            left: 20,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent, width: 2),
                  boxShadow: const [BoxShadow(color: Colors.redAccent, blurRadius: 15, spreadRadius: 2)],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        _vaderGifPath,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Colors.white, size: 80),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Lord Vader sagt:', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(
                            _vaderSpruch, 
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErgebnisScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('Ergebnis')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉 Quiz beendet!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Text('Du hast $_richtigeAntworten von ${_quizDaten.length} richtig!', style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 10),
            Text('⭐ Gesammelte XP: $_aktuelleXP', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber)),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Quiz neu starten'),
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _quizBeendet = false;
                  _aktuelleFrageIndex = 0;
                  _richtigeAntworten = 0;
                  _falscheAntworten = 0;
                  _aktuelleXP = 0;
                  
                  _frageBeantwortet = false;
                  _gewaehlteAntwortIndex = null;
                  _freitextController.clear();
                  _aktuelleStreak = 0; 
                });
                _ladeGemischtesQuiz();
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zurück zum Menü'),
            )
          ],
        ),
      ),
    );
  }
}