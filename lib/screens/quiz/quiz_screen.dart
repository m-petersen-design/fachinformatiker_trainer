import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:sqflite/sqflite.dart'; 
import '../../core/database/database_service.dart';

class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const TypewriterText(this.text, {super.key, required this.style});
  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}
class _TypewriterTextState extends State<TypewriterText> {
  String displayedText = "";
  int charIndex = 0;
  Timer? _timer;
  @override
  void initState() { super.initState(); _type(); }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
  void _type() {
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (charIndex < widget.text.length && mounted) { setState(() { displayedText += widget.text[charIndex]; charIndex++; }); } 
      else { timer.cancel(); }
    });
  }
  @override
  Widget build(BuildContext context) => Text(displayedText + (charIndex < widget.text.length ? "_" : ""), style: widget.style);
}

class ScanlinePainter extends CustomPainter {
  final Color lineColor;
  ScanlinePainter(this.lineColor);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = lineColor.withValues(alpha: 0.15)..strokeWidth = 2.0; 
    for (double i = 0; i < size.height; i += 5) { canvas.drawLine(Offset(0, i), Offset(size.width, i), paint); }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TopologyPainter extends CustomPainter {
  final String type;
  final Color primaryColor;
  final Color surfaceColor;
  TopologyPainter({required this.type, required this.primaryColor, required this.surfaceColor});
  @override
  void paint(Canvas canvas, Size size) {
    final nodePaint = Paint()..color = surfaceColor..style = PaintingStyle.fill;
    final nodeBorderPaint = Paint()..color = primaryColor..style = PaintingStyle.stroke..strokeWidth = 2.0..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    final linePaint = Paint()..color = primaryColor.withValues(alpha: 0.4)..style = PaintingStyle.stroke..strokeWidth = 2.0;

    final double cx = size.width / 2; final double cy = size.height / 2;
    final double radius = math.min(size.width, size.height) * 0.35;
    int numNodes = 5; List<Offset> points = [];
    for (int i = 0; i < numNodes; i++) {
      double angle = (i * 2 * math.pi / numNodes) - math.pi / 2;
      points.add(Offset(cx + radius * math.cos(angle), cy + radius * math.sin(angle)));
    }

    if (type == 'topology_star') {
      final Offset center = Offset(cx, cy);
      for (var point in points) canvas.drawLine(center, point, linePaint);
      for (var point in points) { canvas.drawCircle(point, 12, nodePaint); canvas.drawCircle(point, 12, nodeBorderPaint); }
      canvas.drawCircle(center, 18, nodePaint); canvas.drawCircle(center, 18, nodeBorderPaint..color = Colors.amberAccent);
    } 
    else if (type == 'topology_ring') {
      for (int i = 0; i < numNodes; i++) canvas.drawLine(points[i], points[(i + 1) % numNodes], linePaint);
      for (var point in points) { canvas.drawCircle(point, 12, nodePaint); canvas.drawCircle(point, 12, nodeBorderPaint); }
    } 
    else if (type == 'topology_bus') {
      final double ly = cy; canvas.drawLine(Offset(20, ly), Offset(size.width - 20, ly), linePaint..strokeWidth = 3.0);
      double spacing = (size.width - 60) / (numNodes - 1);
      for (int i = 0; i < numNodes; i++) {
        double nx = 30 + (i * spacing); double ny = (i % 2 == 0) ? ly - 40 : ly + 40; Offset nodePos = Offset(nx, ny);
        canvas.drawLine(Offset(nx, ly), nodePos, linePaint..strokeWidth = 1.5);
        canvas.drawCircle(nodePos, 12, nodePaint); canvas.drawCircle(nodePos, 12, nodeBorderPaint);
      }
    }
    else if (type == 'topology_mesh') {
      for (int i = 0; i < points.length; i++) { for (int j = i + 1; j < points.length; j++) canvas.drawLine(points[i], points[j], linePaint); }
      for (var point in points) { canvas.drawCircle(point, 12, nodePaint); canvas.drawCircle(point, 12, nodeBorderPaint); }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Particle {
  double x, y, speed, size; Color color;
  Particle(this.x, this.y, this.speed, this.size, this.color);
}
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  ParticlePainter(this.particles);
  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final paint = Paint()..color = p.color..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      canvas.drawRect(Rect.fromCenter(center: Offset(p.x, p.y), width: p.size, height: p.size), paint);
    }
  }
  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) => true;
}

class QuizScreen extends StatefulWidget {
  final int themengebietId; final String themengebietName; final int? fachrichtungId; 
  const QuizScreen({super.key, required this.themengebietId, required this.themengebietName, this.fachrichtungId});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true; List<Map<String, dynamic>> _quizDaten = [];
  int _aktuelleFrageIndex = 0; bool _quizBeendet = false; int _richtigeAntworten = 0; int _falscheAntworten = 0; int _aktuelleXP = 0;
  bool _frageBeantwortet = false; int? _gewaehlteAntwortIndex; 
  final _freitextController = TextEditingController();
  int _aktuelleStreak = 0; bool _zeigeVader = false; String _vaderSpruch = ''; String _vaderGifPath = ''; 
  bool _showErrorFlash = false;

  final List<String> _vaderLobGifs = ['assets/vader_lob.gif', 'assets/vader_lob2.gif', 'assets/vader_lob3.gif'];
  final List<String> _vaderKritikGifs = ['assets/vader_kritik.gif', 'assets/vader_kritik2.gif', 'assets/vader_kritik3.gif'];
  final List<String> _vaderLob = ["Die Macht ist stark in dir!", "Beeindruckend.", "Du hast dein Schicksal akzeptiert.", "Die IT-Macht gehorcht dir gut."];
  final List<String> _vaderKritik = ["Ich finde deinen Mangel an Wissen beklagenswert.", "Du hast mich zum letzten Mal enttäuscht.", "Noch bist du kein Jedi-Meister."];

  late AnimationController _particleController;
  final List<Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..addListener(_updateParticles);
    _ladeGemischtesQuiz();
  }

  @override
  void dispose() { _freitextController.dispose(); _particleController.dispose(); super.dispose(); }

  void _initParticles(Size size) {
    if (_particles.isNotEmpty) return;
    for (int i = 0; i < 50; i++) {
      _particles.add(Particle(_random.nextDouble() * size.width, _random.nextDouble() * size.height + size.height, _random.nextDouble() * 3 + 1, _random.nextDouble() * 4 + 2, Colors.cyanAccent.withValues(alpha: _random.nextDouble() * 0.5 + 0.2)));
    }
  }

  void _updateParticles() {
    for (var p in _particles) {
      p.y -= p.speed;
      if (p.y < -10) { p.y = MediaQuery.of(context).size.height + 10; p.x = _random.nextDouble() * MediaQuery.of(context).size.width; }
    }
  }

  Future<void> _ladeGemischtesQuiz() async {
    final db = await DatabaseService.instance.database;
    try { await db.execute("ALTER TABLE frage ADD COLUMN is_favorite INTEGER DEFAULT 0"); } catch (_) {}

    List<Map<String, dynamic>> rawFragen = [];
    if (widget.themengebietId == -1 && widget.fachrichtungId != null) {
      final String jetzt = DateTime.now().toIso8601String();
      rawFragen = await db.rawQuery('SELECT f.* FROM frage f JOIN user_fortschritt uf ON f.id = uf.frage_id JOIN themengebiet t ON f.themengebiet_id = t.id WHERE t.fachrichtung_id = ? AND uf.naechste_faelligkeit <= ?', [widget.fachrichtungId, jetzt]);
    } else {
      rawFragen = await db.query('frage', where: 'themengebiet_id = ?', whereArgs: [widget.themengebietId]);
    }
    List<Map<String, dynamic>> spielbareFragen = rawFragen.map((e) => Map<String, dynamic>.from(e)).toList();
    spielbareFragen.shuffle(); 
    List<Map<String, dynamic>> komplettesQuiz = [];
    for (var frage in spielbareFragen) {
      if (frage['typ'] == 'freitext') { komplettesQuiz.add({'frage': frage, 'antworten': <Map<String, dynamic>>[]}); continue; }
      final rawAntworten = await db.query('antwort_option', where: 'frage_id = ?', whereArgs: [frage['id']]);
      List<Map<String, dynamic>> gemischteAntworten = rawAntworten.map((e) => Map<String, dynamic>.from(e)).toList();
      gemischteAntworten.shuffle(); 
      komplettesQuiz.add({'frage': frage, 'antworten': gemischteAntworten});
    }
    setState(() { _quizDaten = komplettesQuiz; _isLoading = false; });
  }

  void _triggerErrorFlash() {
    HapticFeedback.heavyImpact(); 
    setState(() => _showErrorFlash = true);
    Future.delayed(const Duration(milliseconds: 250), () { if (mounted) setState(() => _showErrorFlash = false); });
  }

  void _pruefeAvatarEinsatz(bool warRichtig) {
    if (warRichtig) {
      _aktuelleStreak++;
      if (_aktuelleStreak > 0 && _aktuelleStreak % 3 == 0) _triggerVaderOverlay(true);
    } else { _aktuelleStreak = 0; _triggerVaderOverlay(false); _triggerErrorFlash(); }
  }

  void _triggerVaderOverlay(bool lob) {
    setState(() {
      _vaderSpruch = lob ? (_vaderLob..shuffle()).first : (_vaderKritik..shuffle()).first;
      _vaderGifPath = lob ? (_vaderLobGifs..shuffle()).first : (_vaderKritikGifs..shuffle()).first;
      _zeigeVader = true;
    });
    Future.delayed(const Duration(seconds: 4), () { if (mounted) setState(() => _zeigeVader = false); });
  }

  Future<void> _updateDailyQuest() async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt('questFragen') ?? 0;
    await prefs.setInt('questFragen', current + 1);
  }

  Future<void> _frageFortschrittSpeichern(int frageId, bool warRichtig) async {
    final db = await DatabaseService.instance.database;
    final String jetzt = DateTime.now().toIso8601String();
    final List<Map<String, dynamic>> result = await db.query('user_fortschritt', where: 'frage_id = ?', whereArgs: [frageId]);
    int altesIntervall = 0, versuche = 0;
    if (result.isNotEmpty) { altesIntervall = result.first['intervall_tage'] as int; versuche = result.first['anzahl_versuche'] as int; }
    int neuesIntervall = warRichtig ? (altesIntervall == 0 ? 1 : altesIntervall * 2) : 0;
    final naechsteFaelligkeit = DateTime.now().add(Duration(days: neuesIntervall)).toIso8601String();
    await db.insert('user_fortschritt', { 'frage_id': frageId, 'korrekt_beantwortet': warRichtig ? 1 : 0, 'anzahl_versuche': versuche + 1, 'letzter_versuch': jetzt, 'naechste_faelligkeit': naechsteFaelligkeit, 'intervall_tage': neuesIntervall, }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  void _mcAntwortAuswerten(int index, dynamic istKorrektRaw) {
    if (_frageBeantwortet) return; 
    HapticFeedback.selectionClick(); 
    
    setState(() {
      _gewaehlteAntwortIndex = index; _frageBeantwortet = true;
      int istKorrekt = (istKorrektRaw is int) ? istKorrektRaw : int.tryParse(istKorrektRaw.toString()) ?? 0;
      bool warRichtig = (istKorrekt == 1);
      if (warRichtig) { _richtigeAntworten++; _aktuelleXP += 10; HapticFeedback.mediumImpact(); } else { _falscheAntworten++; }
      _pruefeAvatarEinsatz(warRichtig);
    });
    final frageId = _quizDaten[_aktuelleFrageIndex]['frage']['id'] as int;
    _frageFortschrittSpeichern(frageId, _gewaehlteAntwortIndex != null && istKorrektRaw.toString() == "1");
  }

  void _freitextSelbstbewertung(bool warRichtig) {
    setState(() { if (warRichtig) { _richtigeAntworten++; _aktuelleXP += 15; HapticFeedback.mediumImpact(); } else { _falscheAntworten++; } _pruefeAvatarEinsatz(warRichtig); });
    final frageId = _quizDaten[_aktuelleFrageIndex]['frage']['id'] as int;
    _frageFortschrittSpeichern(frageId, warRichtig);
    _naechsteFrage();
  }

  Future<void> _xpInDatenbankSpeichern() async {
    if (_aktuelleXP > 0) {
      final db = await DatabaseService.instance.database;
      if (widget.themengebietId == -1 && widget.fachrichtungId != null) await db.rawUpdate('UPDATE fachrichtung SET xp = xp + ? WHERE id = ?', [_aktuelleXP, widget.fachrichtungId]);
      else await db.rawUpdate('UPDATE fachrichtung SET xp = xp + ? WHERE id = (SELECT fachrichtung_id FROM themengebiet WHERE id = ?)', [_aktuelleXP, widget.themengebietId]);
    }
  }

  void _naechsteFrage() {
    _updateDailyQuest(); 
    if (_aktuelleFrageIndex < _quizDaten.length - 1) {
      setState(() { _aktuelleFrageIndex++; _frageBeantwortet = false; _gewaehlteAntwortIndex = null; _freitextController.clear(); });
    } else {
      HapticFeedback.vibrate(); 
      setState(() => _quizBeendet = true);
      _xpInDatenbankSpeichern(); _particleController.repeat(); 
    }
  }

  Widget _buildQuestionImageOrVector(String? path) {
    if (path == null || path.trim().isEmpty) return const SizedBox.shrink();
    if (path.startsWith('topology_')) {
      return Container(
        height: 180, margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1))),
        child: CustomPaint(painter: TopologyPainter(type: path, primaryColor: Theme.of(context).colorScheme.primary, surfaceColor: Theme.of(context).scaffoldBackgroundColor), child: Container()),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 20), constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset(path, fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) => Container(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.broken_image, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)), const SizedBox(width: 10), Text('Bild nicht gefunden', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)))])))),
    );
  }

  Widget _buildTerminalQuestion(String text, String? imgPath) {
    bool isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      decoration: BoxDecoration(
        color: isLight ? Colors.white : Colors.black87,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05), borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
            child: Row(
              children: [
                const CircleAvatar(radius: 4, backgroundColor: Colors.redAccent), const SizedBox(width: 6),
                const CircleAvatar(radius: 4, backgroundColor: Colors.amber), const SizedBox(width: 6),
                const CircleAvatar(radius: 4, backgroundColor: Colors.greenAccent), const SizedBox(width: 12),
                Text('frage_${_aktuelleFrageIndex + 1}.sh', style: GoogleFonts.firaCode(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildQuestionImageOrVector(imgPath),
                TypewriterText(text, style: GoogleFonts.firaCode(fontSize: 16, color: isLight ? Colors.black87 : Colors.cyanAccent, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(appBar: AppBar(title: Text(widget.themengebietName)), body: const Center(child: CircularProgressIndicator()));
    if (_quizDaten.isEmpty) return Scaffold(appBar: AppBar(title: Text(widget.themengebietName)), body: Center(child: Text('Keine Fragen vorhanden.', style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurface))));
    if (_quizBeendet) return _buildErgebnisScreen();

    final aktuelleDaten = _quizDaten[_aktuelleFrageIndex];
    final frage = aktuelleDaten['frage'] as Map<String, dynamic>;
    List<Map<String, dynamic>> antworten = [];
    if (aktuelleDaten['antworten'] != null) antworten = List<dynamic>.from(aktuelleDaten['antworten']).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        title: Text(widget.themengebietName, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)), 
        backgroundColor: Colors.transparent, elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              (frage['is_favorite'] == 1) ? Icons.bookmark : Icons.bookmark_border, 
              color: Theme.of(context).colorScheme.primary
            ),
            onPressed: () async {
              HapticFeedback.selectionClick();
              int newVal = (frage['is_favorite'] == 1) ? 0 : 1;
              final db = await DatabaseService.instance.database;
              await db.rawUpdate('UPDATE frage SET is_favorite = ? WHERE id = ?', [newVal, frage['id']]);
              setState(() { frage['is_favorite'] = newVal; });
              if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(newVal == 1 ? 'Im Holocron Archiv gespeichert!' : 'Aus Archiv entfernt.')));
            },
          )
        ],
      ),
      body: Stack(
        children: [
          Container(color: Theme.of(context).scaffoldBackgroundColor),
          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: ScanlinePainter(Theme.of(context).colorScheme.onSurface)))),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))]),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Row(children: [const Icon(Icons.check_circle, color: Colors.greenAccent, size: 24), const SizedBox(width: 8), Text('$_richtigeAntworten', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold))]),
                        Row(children: [const Icon(Icons.cancel, color: Colors.redAccent, size: 24), const SizedBox(width: 8), Text('$_falscheAntworten', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold))]),
                        Row(children: [const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 24), const SizedBox(width: 8), Text('$_aktuelleStreak', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold))]), 
                        Container(width: 1, height: 30, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)), 
                        Row(children: [Icon(Icons.star, color: Theme.of(context).colorScheme.primary, size: 24), const SizedBox(width: 8), Text('$_aktuelleXP XP', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold))]),
                      ],
                    ),
                  ),
                  Text('Frage ${_aktuelleFrageIndex + 1} von ${_quizDaten.length}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                  const SizedBox(height: 16),
                  
                  _buildTerminalQuestion(frage['frage_text'].toString(), frage['bild_pfad']?.toString()),
                  const SizedBox(height: 30),

                  if (frage['typ'] == 'multiple_choice') ...[
                    ...antworten.asMap().entries.map((entry) {
                      int index = entry.key; var antwort = entry.value;
                      int istKorrekt = (antwort['ist_korrekt'] is int) ? antwort['ist_korrekt'] : int.tryParse(antwort['ist_korrekt'].toString()) ?? 0;
                      Color buttonColor = Theme.of(context).cardColor; Color textColor = Theme.of(context).colorScheme.onSurface;
                      BorderSide border = BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1), width: 1);

                      if (_frageBeantwortet) {
                        if (istKorrekt == 1) { buttonColor = Colors.green.withValues(alpha: 0.2); textColor = Colors.green; border = const BorderSide(color: Colors.green, width: 2); } 
                        else if (_gewaehlteAntwortIndex == index) { buttonColor = Colors.red.withValues(alpha: 0.2); textColor = Colors.red; border = const BorderSide(color: Colors.red, width: 2); }
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: buttonColor, foregroundColor: textColor, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16), alignment: Alignment.centerLeft, side: border),
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
                          decoration: BoxDecoration(color: Theme.of(context).cardColor, border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4), width: 1.5), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), blurRadius: 10)]),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [Icon(Icons.lightbulb_outline, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), Text('Erklärung:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.primary))]),
                              const SizedBox(height: 12),
                              Text(frage['erklaerung'].toString(), style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15, height: 1.5)),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      ElevatedButton(style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)), onPressed: _naechsteFrage, child: const Text('Nächste Frage ➔', style: TextStyle(fontSize: 18)))
                    ]
                  ] else ...[
                    TextField(controller: _freitextController, maxLines: 5, enabled: !_frageBeantwortet, style: TextStyle(color: Theme.of(context).colorScheme.onSurface), decoration: const InputDecoration(labelText: 'Deine Antwort', border: OutlineInputBorder())),
                    const SizedBox(height: 20),
                    if (!_frageBeantwortet)
                      ElevatedButton.icon(style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)), onPressed: () { if(_freitextController.text.isNotEmpty) setState(()=>_frageBeantwortet=true); }, icon: const Icon(Icons.check), label: const Text('Musterlösung prüfen', style: TextStyle(fontSize: 16)))
                    else ...[
                      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Theme.of(context).cardColor, border: Border.all(color: Colors.green), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('✅ Musterlösung:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)), const SizedBox(height: 8), Text(frage['erklaerung']?.toString() ?? 'Keine Musterlösung hinterlegt.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))])),
                      const SizedBox(height: 30),
                      Text('War deine Antwort sinngemäß richtig?', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                      const SizedBox(height: 16),
                      Row(children: [Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withValues(alpha: 0.2), foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 16)), onPressed: () => _freitextSelbstbewertung(false), child: const Text('❌ Nein'))), const SizedBox(width: 16), Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green.withValues(alpha: 0.2), foregroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 16)), onPressed: () => _freitextSelbstbewertung(true), child: const Text('✅ Ja (+15 XP)')))]),
                    ]
                  ],
                ],
              ),
            ),
          ),
          
          IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(border: Border.all(color: _showErrorFlash ? Colors.redAccent : Colors.transparent, width: _showErrorFlash ? 8 : 0), color: _showErrorFlash ? Colors.red.withValues(alpha: 0.15) : Colors.transparent),
            ),
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 600), curve: Curves.elasticOut,
            bottom: _zeigeVader ? 20 : -300, left: 20, right: 20,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.error, width: 2), boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3), blurRadius: 15, spreadRadius: 2)]),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      // GROSSES FEEDBACK-GIF: 150x150
                      child: Image.asset(_vaderGifPath, width: 150, height: 150, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Icon(Icons.person, color: Theme.of(context).colorScheme.onSurface, size: 80))
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Lord Vader sagt:', style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 4), Text(_vaderSpruch, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontStyle: FontStyle.italic))])),
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
    _initParticles(MediaQuery.of(context).size);
    return Scaffold(
      appBar: AppBar(title: const Text('Ergebnis')),
      body: Stack(
        children: [
          Positioned.fill(child: AnimatedBuilder(animation: _particleController, builder: (context, child) => CustomPaint(painter: ParticlePainter(_particles)))),
          Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: Theme.of(context).cardColor.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(24), border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5))),
              child: Column(
                mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🎉 Quiz beendet!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 20),
                  Text('Du hast $_richtigeAntworten von ${_quizDaten.length} richtig!', style: TextStyle(fontSize: 20, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8))),
                  const SizedBox(height: 10),
                  Text('⭐ Gesammelte XP: $_aktuelleXP', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh), label: const Text('Neu starten'),
                    onPressed: () {
                      _particleController.stop();
                      setState(() {
                        _isLoading = true; _quizBeendet = false; _aktuelleFrageIndex = 0;
                        _richtigeAntworten = 0; _falscheAntworten = 0; _aktuelleXP = 0;
                        _frageBeantwortet = false; _gewaehlteAntwortIndex = null; _freitextController.clear(); _aktuelleStreak = 0; 
                      });
                      _ladeGemischtesQuiz();
                    },
                  ),
                  const SizedBox(height: 16),
                  TextButton(onPressed: () { _particleController.stop(); Navigator.pop(context); }, child: Text('Zurück zum Menü', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))))
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}