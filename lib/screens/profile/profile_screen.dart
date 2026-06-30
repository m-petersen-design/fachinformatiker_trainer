import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // Leistungsstarkes Drittanbieter-Paket für Graphen und Diagramme
import '../../core/database/database_service.dart';
import '../../models/fachrichtung.dart';

/// **UI-Komponente: ProfileScreen**
/// Visualisiert die Meta-Daten (XP, Streaks, Ränge) des Nutzers.
/// Dieser Screen ist stark von Gamification-Konzepten geprägt, um die Langzeitmotivation 
/// der Azubis (Retention Rate) hoch zu halten.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // --- STATE-VARIABLEN ---
  bool _isLoading = true;
  int _globalXP = 0;
  int _streak = 0;
  List<Fachrichtung> _fachrichtungen = [];

  // Inline-Editing State (Für das Ändern des Nutzernamens)
  String _userName = 'Terminal-Held';
  bool _isEditingName = false;
  final TextEditingController _nameController = TextEditingController();

  // --- WIDGET LIFECYCLE ---
  @override
  void initState() {
    super.initState();
    _ladeProfilDaten();
  }

  // --- DATENBANK LOGIK ---

  /// **Lädt und aggregiert die globalen User-Stats**
  Future<void> _ladeProfilDaten() async {
    final db = await DatabaseService.instance.database;
    
    // --- DATENBANK-MIGRATION (Fail-Safe) ---
    // Update-Logik: Falls die App von einer Version gestartet wird, 
    // die noch keine 'user_name' Spalte besaß, wird diese hier zerstörungsfrei nachgerüstet.
    try { await db.execute("ALTER TABLE user_stats ADD COLUMN user_name TEXT DEFAULT 'Terminal-Held'"); } catch (_) {} 

    final userStats = await db.query('user_stats', where: 'id = 1');
    int currentStreak = 0;
    String loadedName = 'Terminal-Held';
    
    if (userStats.isNotEmpty) {
      currentStreak = userStats.first['streak_tage'] as int;
      try { loadedName = userStats.first['user_name'] as String? ?? 'Terminal-Held'; } catch (_) {}
    }

    // Liest die XP aus den einzelnen Fachrichtungen aus und rechnet sie zusammen
    final List<Map<String, dynamic>> maps = await db.query('fachrichtung');
    int totalXp = 0;
    final fachList = List.generate(maps.length, (i) {
      final xp = maps[i]['xp'] as int? ?? 0;
      totalXp += xp; // Aggregation
      return Fachrichtung(
        id: maps[i]['id'] as int, name: maps[i]['name'] as String,
        kuerzel: maps[i]['kuerzel'] as String, beschreibung: maps[i]['beschreibung']?.toString() ?? '',
        farbeHex: maps[i]['farbe_hex']?.toString() ?? '#00E5FF', xp: xp,
      );
    });

    setState(() {
      _fachrichtungen = fachList; _globalXP = totalXp; _streak = currentStreak;
      _userName = loadedName; _nameController.text = loadedName; _isLoading = false;
    });
  }

  /// **Speichert den neuen Namen in der DB**
  Future<void> _saveName() async {
    // Verhindert das Speichern von leeren Strings
    if (_nameController.text.trim().isEmpty) return;
    final db = await DatabaseService.instance.database;
    
    await db.update('user_stats', {'user_name': _nameController.text.trim()}, where: 'id = 1');
    setState(() { _userName = _nameController.text.trim(); _isEditingName = false; });
  }

  // --- GAMIFICATION LOGIK ---

  /// **Berechnet den RPG-Rang basierend auf der Gesamt-XP**
  /// Ein klassisches Switch-Case/If-Else Pattern für Gamification-Level.
  String _getITRank(int xp) {
    if (xp >= 5000) return 'BHH-Endboss';
    if (xp >= 3000) return 'Arch-Linux-Prediger';
    if (xp >= 1500) return 'Proxmox-Dompteur';
    if (xp >= 500) return '2nd-Level-Zauberer';
    if (xp >= 100) return 'Ticket-Schubser';
    return 'Drucker-Neustarter'; // Einstiegs-Level
  }

  // --- UI RENDER METHODEN (Modularisierung) ---

  /// **Zeichnet eine quadratische Statistik-Kachel (XP & Streak)**
  Widget _buildStatBox(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1D2229), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 13, color: Colors.white54), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  /// **Zeichnet den LineChart-Graphen für den Fortschritt**
  Widget _buildPerformanceChart() {
    return Container(
      height: 200, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1D2229), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Performance (Letzte 7 Tage)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                // Minimalistisches Design: Versteckt störende Gitterlinien und Achsenbeschriftungen
                gridData: const FlGridData(show: false), titlesData: const FlTitlesData(show: false), borderData: FlBorderData(show: false),
                minX: 0, maxX: 6, minY: 0, maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    // Mock-Daten für den Prototypen. Für ein Enterprise-Release müssten diese 
                    // Spots (x=Tag, y=XP) dynamisch aus einer History-Tabelle der DB geladen werden.
                    spots: const [FlSpot(0, 10), FlSpot(1, 30), FlSpot(2, 25), FlSpot(3, 50), FlSpot(4, 60), FlSpot(5, 45), FlSpot(6, 90)], 
                    isCurved: true, color: Theme.of(context).colorScheme.primary, barWidth: 4,
                    isStrokeCapRound: true, dotData: const FlDotData(show: false),
                    // Erzeugt eine hübsche, halbtransparente Füllung unterhalb der Linie
                    belowBarData: BarAreaData(show: true, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// **Zeichnet eine Errungenschaft (Tech-Badge)**
  Widget _buildBadge(String title, IconData icon, bool isUnlocked, Color glowColor) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // Ist das Badge noch nicht freigeschaltet, wird es ausgegraut
        color: isUnlocked ? glowColor.withValues(alpha: 0.1) : Colors.black26,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isUnlocked ? glowColor : Colors.white10, width: 1.5),
        boxShadow: isUnlocked ? [BoxShadow(color: glowColor.withValues(alpha: 0.2), blurRadius: 10, spreadRadius: 1)] : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isUnlocked ? glowColor : Colors.white24, size: 36),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isUnlocked ? Colors.white : Colors.white38)),
        ],
      ),
    );
  }

  // --- HAUPT-UI RENDER TREE ---
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Profil'), backgroundColor: Colors.transparent),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --- AVATAR BILD ---
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3), boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 2)]),
              child: const CircleAvatar(backgroundColor: Color(0xFF1D2229), child: Icon(Icons.person, size: 60, color: Colors.white)),
            ),
            const SizedBox(height: 20),
            
            // --- INLINE EDITING LOGIK (Name des Nutzers) ---
            _isEditingName
                // EDITIER-MODUS: Zeigt ein Textfeld und einen Speicher-Button
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 200, child: TextField(controller: _nameController, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), decoration: const InputDecoration(isDense: true), onSubmitted: (_) => _saveName())),
                      IconButton(icon: const Icon(Icons.check, color: Colors.greenAccent), onPressed: _saveName),
                    ],
                  )
                // ANZEIGE-MODUS: Klickt der User auf den Namen, wechselt der Boolean _isEditingName
                : GestureDetector(
                    onTap: () => setState(() => _isEditingName = true),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [Text(_userName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(width: 8), const Icon(Icons.edit, size: 18, color: Colors.white54)]),
                  ),
            
            const SizedBox(height: 6),
            
            // --- RPG RANG ---
            Text(_getITRank(_globalXP), style: const TextStyle(fontSize: 18, color: Colors.cyanAccent, fontStyle: FontStyle.italic)),
            const SizedBox(height: 30),

            // --- KACHELN ---
            Row(children: [_buildStatBox('Gesamt XP', '$_globalXP', Icons.star, Theme.of(context).colorScheme.primary), const SizedBox(width: 16), _buildStatBox('Streak', '$_streak', Icons.local_fire_department, Colors.orangeAccent)]),
            const SizedBox(height: 24),
            
            // --- PERFORMANCE GRAPH ---
            _buildPerformanceChart(),
            
            const SizedBox(height: 36),
            
            // --- BADGES (Errungenschaften) ---
            const Align(alignment: Alignment.centerLeft, child: Text('Errungenschaften', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.1))),
            const SizedBox(height: 16),
            SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal, // Swipe nach links/rechts
                children: [
                  // Die Boolean-Bedingung entscheidet, ob das Badge farbig leuchtet oder grau bleibt
                  _buildBadge('Boot-Up', Icons.power_settings_new, _globalXP > 0, Colors.greenAccent),
                  _buildBadge('Dauerbetrieb', Icons.battery_charging_full, _streak >= 7, Colors.orangeAccent),
                  _buildBadge('XP-Junkie', Icons.military_tech, _globalXP >= 1000, Colors.amber),
                  _buildBadge('Arch-User', Icons.terminal, _globalXP >= 3000, Colors.cyanAccent),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // --- FACH-FORTSCHRITT (Mini-Ladebalken) ---
            const Align(alignment: Alignment.centerLeft, child: Text('Fach-Fortschritt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.1))),
            const SizedBox(height: 16),

            // Filtere die Liste: Zeige nur Fachrichtungen an, in denen der User schon > 0 XP gesammelt hat
            ..._fachrichtungen.where((f) => f.xp > 0).map((fach) {
              Color accentColor = Color(int.parse(fach.farbeHex.replaceAll('#', '0xFF')));
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(fach.kuerzel, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), Text('${fach.xp} XP', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold))]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      // TweenAnimationBuilder lässt den Fortschrittsbalken weich von 0 auf den echten Wert wachsen
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: (fach.xp % 100) / 100),
                        duration: const Duration(seconds: 1), curve: Curves.easeOutCubic,
                        builder: (context, value, _) => LinearProgressIndicator(value: value, minHeight: 8, color: accentColor, backgroundColor: Colors.white10),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}