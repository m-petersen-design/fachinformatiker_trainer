import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/database/database_service.dart';
import '../../models/fachrichtung.dart';
import '../quiz/quiz_screen.dart';

// ==========================================
// 1. WIEDERVERWENDBARE UI-KOMPONENTEN (DRY-Prinzip)
// ==========================================

/// **TypewriterText**
/// Isoliertes Widget für den Schreibmaschinen-Effekt im Terminal.
/// Da es einen eigenen State und Timer hat, belastet es nicht den 
/// Neulade-Zyklus (Rebuild) des gesamten Bildschirms.
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
  void initState() {
    super.initState();
    _type();
  }
  
  @override
  void dispose() { 
    _timer?.cancel(); // Verhindert Memory Leaks, wenn das Terminal ausgeblendet wird
    super.dispose(); 
  }

  void _type() {
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (charIndex < widget.text.length && mounted) {
        setState(() { displayedText += widget.text[charIndex]; charIndex++; });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) => Text(displayedText + (charIndex < widget.text.length ? "_" : ""), style: widget.style);
}

/// **BounceCard (Animation Wrapper)**
/// Ein generischer Wrapper für Listen-Elemente. Kapselt die Animation (ScaleTransition) 
/// und das haptische Feedback. So bleibt der Haupt-Code sauber und übersichtlich.
class BounceCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const BounceCard({super.key, required this.child, required this.onTap});
  @override
  State<BounceCard> createState() => _BounceCardState();
}

class _BounceCardState extends State<BounceCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }
  
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) { HapticFeedback.lightImpact(); _controller.reverse(); widget.onTap(); },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

// ==========================================
// 2. HAUPT-SCREEN (Themen-Übersicht)
// ==========================================

/// **UI-Komponente: ThemenScreen**
/// Zeigt alle Unterkategorien (z.B. Netzwerke, Datenbanken) einer übergebenen 
/// Fachrichtung (z.B. FISI) an. 
class ThemenScreen extends StatefulWidget {
  // Dependency Injection: Der Screen erfordert zwingend eine Fachrichtung, um zu funktionieren.
  final Fachrichtung fachrichtung;
  const ThemenScreen({super.key, required this.fachrichtung});
  
  @override
  State<ThemenScreen> createState() => _ThemenScreenState();
}

class _ThemenScreenState extends State<ThemenScreen> {
  // --- STATE VARIABLEN ---
  bool _isLoading = true;
  List<Map<String, dynamic>> _themen = [];
  int _faelligeFragenCount = 0; // Hält die Anzahl der Fragen, die heute wiederholt werden müssen

  @override
  void initState() {
    super.initState();
    _ladeDaten();
  }

  // --- DATENBANK & LOGIK ---

  /// **Zieht die Themengebiete und berechnet den Spaced-Repetition-Bedarf**
  Future<void> _ladeDaten() async {
    final db = await DatabaseService.instance.database;
    final String jetzt = DateTime.now().toIso8601String();
    
    // 1. Lade alle Themengebiete, die zur übergebenen Fachrichtung gehören
    final themen = await db.query('themengebiet', where: 'fachrichtung_id = ?', whereArgs: [widget.fachrichtung.id]);
    
    // 2. Komplexe relationale Abfrage (SQL JOIN)
    // Zählt alle Fragen über alle Themengebiete dieser Fachrichtung hinweg zusammen, 
    // deren 'naechste_faelligkeit' in der Vergangenheit liegt.
    final countResult = await db.rawQuery('''
      SELECT COUNT(f.id) as count FROM frage f
      JOIN user_fortschritt uf ON f.id = uf.frage_id
      JOIN themengebiet t ON f.themengebiet_id = t.id
      WHERE t.fachrichtung_id = ? AND uf.naechste_faelligkeit <= ?
    ''', [widget.fachrichtung.id, jetzt]);

    int count = 0;
    if (countResult.isNotEmpty) {
      count = countResult.first['count'] as int;
    }

    setState(() { _themen = themen; _faelligeFragenCount = count; _isLoading = false; });
  }

  /// **Refresh-Methode**
  /// Wird aufgerufen, wenn der Nutzer die Liste nach unten zieht (Pull-to-Refresh) 
  /// oder vom Quiz zurückkehrt, um die fälligen Fragen neu zu berechnen.
  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    await _ladeDaten();
  }

  // --- WIDGET BUILDER ---

  /// **Das System-Log Terminal (Gamification UI)**
  /// Ein dynamisches Widget, das seinen Zustand (Farbe, Text) komplett 
  /// an die Menge der fälligen Fragen anpasst.
  Widget _buildSystemLogTerminal() {
    bool hasWarnings = _faelligeFragenCount > 0;
    Color terminalColor = hasWarnings ? Colors.orangeAccent : Colors.green;
    String status = hasWarnings ? '[WARN] Systemstabilität gefährdet.' : '[OK] System nominal.';
    String message = hasWarnings 
      ? '$_faelligeFragenCount Datenfragmente erfordern sofortige Re-Kalibrierung (Spaced Repetition).' 
      : 'Keine Speicherlücken im Langzeitarchiv erkannt.';

    bool isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      decoration: BoxDecoration(
        color: isLight ? Colors.white : Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: terminalColor.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [BoxShadow(color: terminalColor.withValues(alpha: 0.15), blurRadius: 10, spreadRadius: 1)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: terminalColor.withValues(alpha: 0.1), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
            child: Row(
              children: [
                Icon(Icons.terminal, color: terminalColor, size: 16),
                const SizedBox(width: 8),
                Text('sys_log_daemon.exe', style: GoogleFonts.firaCode(color: terminalColor, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status, style: GoogleFonts.firaCode(color: terminalColor, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TypewriterText('> $message', style: GoogleFonts.firaCode(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8), fontSize: 13)),
                
                // RENDERING BEDINGUNG: Der "Reparieren"-Button erscheint nur, wenn Fragen fällig sind.
                if (hasWarnings) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: terminalColor.withValues(alpha: 0.2), 
                        foregroundColor: terminalColor, 
                        side: BorderSide(color: terminalColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.play_arrow), 
                      label: Text('Re-Kalibrierung starten', style: GoogleFonts.firaCode(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        HapticFeedback.selectionClick();
                        // Startet ein "gemischtes" Quiz (themengebietId = -1) für alle fälligen Fragen dieser Fachrichtung
                        await Navigator.push(context, MaterialPageRoute(builder: (context) => QuizScreen(themengebietId: -1, themengebietName: '🔥 Schwächen (${widget.fachrichtung.kuerzel})', fachrichtungId: widget.fachrichtung.id)));
                        // Wenn der User aus dem Quiz zurückkommt, wird die Liste aktualisiert.
                        _refresh();
                      },
                    ),
                  )
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- HAUPT UI RENDER TREE ---
  @override
  Widget build(BuildContext context) {
    // Parst die Hex-Farbe dynamisch aus der Datenbank für konsistentes Branding
    Color accentColor = Color(int.parse(widget.fachrichtung.farbeHex.replaceAll('#', '0xFF')));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- HERO ANIMATION ---
            // Verbindet das Kürzel-Badge (z.B. FISI) visuell mit dem vorherigen Dashboard-Screen.
            // Flutter interpoliert Größe und Position automatisch für einen flüssigen Übergang.
            Hero(
              tag: 'fach_banner_${widget.fachrichtung.id}',
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(100), border: Border.all(color: accentColor, width: 1.5)),
                  child: Text(widget.fachrichtung.kuerzel, style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(child: Text(widget.fachrichtung.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).colorScheme.onSurface), overflow: TextOverflow.ellipsis)),
          ],
        ),
        backgroundColor: Colors.transparent, elevation: 0, centerTitle: false,
        // Sorgt dafür, dass die Schrift lesbar bleibt, wenn Text hinter die AppBar gescrollt wird
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.9), Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.0)]),
          ),
        ),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: accentColor))
        : RefreshIndicator(
            onRefresh: _refresh, color: accentColor, backgroundColor: Theme.of(context).cardColor,
            child: ListView(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20, bottom: 40, left: 16, right: 16),
              children: [
                
                _buildSystemLogTerminal(),
                
                Padding(
                  padding: const EdgeInsets.only(top: 36.0, bottom: 16.0, left: 4.0),
                  child: Text('Lern-Module', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), letterSpacing: 1.1)),
                ),

                // Fallback, falls der Admin eine Fachrichtung angelegt, aber noch keine Themen hinzugefügt hat
                if (_themen.isEmpty)
                  Padding(padding: const EdgeInsets.all(20.0), child: Center(child: Text('Noch keine Module vorhanden.', style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)))))
                else
                  ..._themen.map((thema) => BounceCard(
                    onTap: () async {
                      // Klassischer Modus: Startet ein Quiz spezifisch für ein Themengebiet (z.B. nur SQL)
                      await Navigator.push(context, MaterialPageRoute(builder: (context) => QuizScreen(themengebietId: thema['id'] as int, themengebietName: thema['name'].toString())));
                      _refresh();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4))]),
                      child: Stack(
                        children: [
                          // Wasserzeichen-Effekt (Große, durchsichtige Buchstaben im Hintergrund der Kachel)
                          Positioned(
                            right: -20, bottom: -10,
                            child: Text(
                              thema['name'].toString().toUpperCase().replaceAll(' ', ''),
                              style: GoogleFonts.orbitron(fontSize: 50, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.02)),
                            ),
                          ),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                              child: Icon(Icons.folder_open, color: accentColor, size: 28),
                            ),
                            title: Text(thema['name'].toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
                            trailing: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05), shape: BoxShape.circle),
                              child: Icon(Icons.arrow_forward_ios, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
              ],
            ),
          ),
    );
  }
}