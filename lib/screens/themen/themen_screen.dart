import 'package:flutter/material.dart';
import '../../core/database/database_service.dart';
import '../../models/fachrichtung.dart';
import '../quiz/quiz_screen.dart';

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
    
    final themen = await db.query(
      'themengebiet',
      where: 'fachrichtung_id = ?',
      whereArgs: [widget.fachrichtung.id],
    );

    final countResult = await db.rawQuery('''
      SELECT COUNT(f.id) as count 
      FROM frage f
      JOIN user_fortschritt uf ON f.id = uf.frage_id
      JOIN themengebiet t ON f.themengebiet_id = t.id
      WHERE t.fachrichtung_id = ? 
        AND uf.naechste_faelligkeit <= ?
    ''', [widget.fachrichtung.id, jetzt]);

    int count = 0;
    if (countResult.isNotEmpty) {
      count = countResult.first['count'] as int;
    }

    setState(() {
      _themen = themen;
      _faelligeFragenCount = count;
      _isLoading = false;
    });
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    await _ladeDaten();
  }

  @override
  Widget build(BuildContext context) {
    Color accentColor = Color(int.parse(widget.fachrichtung.farbeHex.replaceAll('#', '0xFF')));
    Color surfaceColor = const Color(0xFF1D2229); 

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.fachrichtung.name, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF121419).withValues(alpha: 0.9),
                const Color(0xFF121419).withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: accentColor))
        : RefreshIndicator(
            onRefresh: _refresh,
            color: accentColor,
            backgroundColor: surfaceColor,
            child: ListView(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20, bottom: 40, left: 16, right: 16),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _faelligeFragenCount > 0 ? Colors.orangeAccent.withValues(alpha: 0.5) : Colors.greenAccent.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _faelligeFragenCount > 0 ? Colors.orangeAccent.withValues(alpha: 0.1) : Colors.transparent,
                        blurRadius: 15,
                        spreadRadius: 2,
                      )
                    ]
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _faelligeFragenCount > 0 ? Icons.local_fire_department : Icons.check_circle_outline,
                              color: _faelligeFragenCount > 0 ? Colors.orangeAccent : Colors.greenAccent,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Schwächen-Trainer',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: _faelligeFragenCount > 0 ? Colors.orangeAccent : Colors.greenAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _faelligeFragenCount > 0 
                            ? 'Du hast $_faelligeFragenCount Fragen fällig. Wiederhole sie jetzt, um deine Lücken zu schließen!'
                            : 'Alles perfekt! Dein Langzeitgedächtnis ist aktuell up-to-date.',
                          style: const TextStyle(fontSize: 15, color: Colors.white70, height: 1.4),
                        ),
                        if (_faelligeFragenCount > 0) ...[
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orangeAccent,
                                foregroundColor: Colors.black87,
                                elevation: 8,
                                shadowColor: const Color(0x66FFAB40), 
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16.0))),
                              ),
                              icon: const Icon(Icons.fitness_center),
                              label: const Text('Jetzt trainieren', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => QuizScreen(
                                      themengebietId: -1, 
                                      themengebietName: '🔥 Schwächen (${widget.fachrichtung.kuerzel})',
                                      fachrichtungId: widget.fachrichtung.id, 
                                    ),
                                  ),
                                );
                                _refresh();
                              },
                            ),
                          )
                        ]
                      ],
                    ),
                  ),
                ),
                
                const Padding(
                  padding: EdgeInsets.only(top: 36.0, bottom: 16.0, left: 4.0),
                  child: Text('Lern-Module', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.1)),
                ),

                if (_themen.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Center(child: Text('Noch keine Module vorhanden.\nLade JSON-Dateien hoch!', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.4), height: 1.5))),
                  )
                else
                  ..._themen.map((thema) => Container(
                    margin: const EdgeInsets.only(bottom: 12.0),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.folder_open, color: accentColor, size: 28),
                      ),
                      title: Text(thema['name'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                      trailing: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => QuizScreen(
                              themengebietId: thema['id'] as int,
                              themengebietName: thema['name'].toString(),
                            ),
                          ),
                        );
                        _refresh();
                      },
                    ),
                  )),
              ],
            ),
          ),
    );
  }
}