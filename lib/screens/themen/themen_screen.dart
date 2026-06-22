import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/database/database_service.dart';
import '../../models/fachrichtung.dart';
import '../quiz/quiz_screen.dart';

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
      onTapUp: (_) { _controller.reverse(); widget.onTap(); },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

class ThemenScreen extends StatefulWidget {
  final Fachrichtung fachrichtung;
  const ThemenScreen({super.key, required this.fachrichtung});
  @override
  State<ThemenScreen> createState() => _ThemenScreenState();
}

class _ThemenScreenState extends State<ThemenScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _themen = [];
  int _faelligeFragenCount = 0;

  @override
  void initState() {
    super.initState();
    _ladeDaten();
  }

  Future<void> _ladeDaten() async {
    final db = await DatabaseService.instance.database;
    final String jetzt = DateTime.now().toIso8601String();
    
    final themen = await db.query('themengebiet', where: 'fachrichtung_id = ?', whereArgs: [widget.fachrichtung.id]);
    final countResult = await db.rawQuery('''
      SELECT COUNT(f.id) as count FROM frage f
      JOIN user_fortschritt uf ON f.id = uf.frage_id
      JOIN themengebiet t ON f.themengebiet_id = t.id
      WHERE t.fachrichtung_id = ? AND uf.naechste_faelligkeit <= ?
    ''', [widget.fachrichtung.id, jetzt]);

    int count = 0;
    if (countResult.isNotEmpty) count = countResult.first['count'] as int;

    setState(() { _themen = themen; _faelligeFragenCount = count; _isLoading = false; });
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    await _ladeDaten();
  }

  @override
  Widget build(BuildContext context) {
    Color accentColor = Color(int.parse(widget.fachrichtung.farbeHex.replaceAll('#', '0xFF')));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // EMPFÄNGER FÜR DIE HERO ANIMATION
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
            Flexible(child: Text(widget.fachrichtung.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis)),
          ],
        ),
        backgroundColor: Colors.transparent, elevation: 0, centerTitle: false,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xFF121419).withValues(alpha: 0.9), const Color(0xFF121419).withValues(alpha: 0.0)]),
          ),
        ),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: accentColor))
        : RefreshIndicator(
            onRefresh: _refresh, color: accentColor, backgroundColor: const Color(0xFF1D2229),
            child: ListView(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20, bottom: 40, left: 16, right: 16),
              children: [
                // GLASSMORPHISMUS FÜR DEN TRAINER
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D2229).withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _faelligeFragenCount > 0 ? Colors.orangeAccent.withValues(alpha: 0.5) : Colors.greenAccent.withValues(alpha: 0.3), width: 2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(_faelligeFragenCount > 0 ? Icons.local_fire_department : Icons.check_circle_outline, color: _faelligeFragenCount > 0 ? Colors.orangeAccent : Colors.greenAccent, size: 32),
                                const SizedBox(width: 12),
                                Text('Schwächen-Trainer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: _faelligeFragenCount > 0 ? Colors.orangeAccent : Colors.greenAccent)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _faelligeFragenCount > 0 ? 'Du hast $_faelligeFragenCount Fragen fällig. Wiederhole sie jetzt!' : 'Alles perfekt! Dein Gedächtnis ist up-to-date.',
                              style: const TextStyle(fontSize: 15, color: Colors.white70, height: 1.4),
                            ),
                            if (_faelligeFragenCount > 0) ...[
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black87, shadowColor: const Color(0x66FFAB40), padding: const EdgeInsets.symmetric(vertical: 16)),
                                  icon: const Icon(Icons.fitness_center), label: const Text('Jetzt trainieren'),
                                  onPressed: () async {
                                    await Navigator.push(context, MaterialPageRoute(builder: (context) => QuizScreen(themengebietId: -1, themengebietName: '🔥 Schwächen (${widget.fachrichtung.kuerzel})', fachrichtungId: widget.fachrichtung.id)));
                                    _refresh();
                                  },
                                ),
                              )
                            ]
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                const Padding(
                  padding: EdgeInsets.only(top: 36.0, bottom: 16.0, left: 4.0),
                  child: Text('Lern-Module', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.1)),
                ),

                if (_themen.isEmpty)
                  Padding(padding: const EdgeInsets.all(20.0), child: Center(child: Text('Noch keine Module vorhanden.', style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.4)))))
                else
                  ..._themen.map((thema) => BounceCard(
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (context) => QuizScreen(themengebietId: thema['id'] as int, themengebietName: thema['name'].toString())));
                      _refresh();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      decoration: BoxDecoration(color: const Color(0xFF1D2229), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 4))]),
                      child: Stack(
                        children: [
                          // SCI-FI EASTER EGG: Subtiles Tech-Wasserzeichen (Aurebesh Style)
                          Positioned(
                            right: -20, bottom: -10,
                            child: Text(
                              thema['name'].toString().toUpperCase().replaceAll(' ', ''),
                              style: GoogleFonts.orbitron(fontSize: 50, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.02)),
                            ),
                          ),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                              child: Icon(Icons.folder_open, color: accentColor, size: 28),
                            ),
                            title: Text(thema['name'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                            trailing: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle),
                              child: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
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