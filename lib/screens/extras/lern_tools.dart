import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/database/database_service.dart';

// ==========================================
// 1. HOLOCRON ARCHIV (Favoriten)
// ==========================================
class HolocronScreen extends StatefulWidget {
  const HolocronScreen({super.key});
  @override
  State<HolocronScreen> createState() => _HolocronScreenState();
}

class _HolocronScreenState extends State<HolocronScreen> {
  List<Map<String, dynamic>> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final db = await DatabaseService.instance.database;
    try { 
      await db.execute("ALTER TABLE frage ADD COLUMN is_favorite INTEGER DEFAULT 0"); 
    } catch (_) {}
    final favs = await db.query('frage', where: 'is_favorite = 1');
    setState(() { _favorites = favs; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Holocron Archiv')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _favorites.isEmpty 
          ? const Center(child: Text('Keine Fragen im Archiv gespeichert.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _favorites.length,
              itemBuilder: (context, index) {
                final frage = _favorites[index];
                return Card(
                  child: ListTile(
                    leading: Icon(Icons.bookmark, color: Theme.of(context).colorScheme.primary),
                    title: Text(frage['frage_text'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text('ID: ${frage['id']} | Typ: ${frage['typ']}'),
                    onTap: () => _showDetails(context, frage),
                  ),
                );
              },
            ),
    );
  }

  void _showDetails(BuildContext context, Map<String, dynamic> frage) {
    showModalBottomSheet(
      context: context, backgroundColor: Theme.of(context).cardColor,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Frage', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(frage['frage_text'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Text('Erklärung / Lösung', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(frage['erklaerung']?.toString() ?? 'Keine Erklärung hinterlegt.', style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. FLASHCARDS (Schnelles Auswendiglernen)
// ==========================================
class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});
  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  List<Map<String, dynamic>> _cards = [];
  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    final db = await DatabaseService.instance.database;
    final questions = await db.query('frage'); 
    List<Map<String, dynamic>> shuffled = List.from(questions)..shuffle();
    setState(() { _cards = shuffled.take(50).toList(); _isLoading = false; }); 
  }

  void _nextCard() {
    HapticFeedback.lightImpact();
    setState(() {
      _showAnswer = false;
      if (_currentIndex < _cards.length - 1) {
        _currentIndex++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_cards.isEmpty) return const Scaffold(body: Center(child: Text('Keine Karten verfügbar.')));

    final currentCard = _cards[_currentIndex];

    return Scaffold(
      appBar: AppBar(title: Text('Flashcards (${_currentIndex + 1}/${_cards.length})')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _showAnswer = !_showAnswer);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: _showAnswer ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: _showAnswer ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_showAnswer ? Icons.lightbulb : Icons.help_outline, color: Theme.of(context).colorScheme.primary, size: 48),
                        const SizedBox(height: 24),
                        Text(
                          _showAnswer ? (currentCard['erklaerung']?.toString().isNotEmpty == true ? currentCard['erklaerung'].toString() : 'Lösung in den Multiple-Choice Optionen.') : currentCard['frage_text'].toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                        ),
                        const SizedBox(height: 30),
                        Text(_showAnswer ? 'Tippe zum Umdrehen' : 'Tippe für die Lösung', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withValues(alpha: 0.2), foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 20)),
                    onPressed: _nextCard, child: const Text('❌ Wusste ich nicht'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.withValues(alpha: 0.2), foregroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 20)),
                    onPressed: _nextCard, child: const Text('✅ Wusste ich'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. IHK PRÜFUNGS-SIMULATION
// ==========================================
class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key});
  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  List<Map<String, dynamic>> _examData = [];
  bool _isLoading = true;
  int _timeRemaining = 3600; 
  Timer? _timer;
  int _answeredCount = 0;

  @override
  void initState() {
    super.initState();
    _loadExam();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining > 0) {
        if (mounted) {
          setState(() => _timeRemaining--);
        }
      } else {
        _finishExam();
      }
    });
  }

  Future<void> _loadExam() async {
    final db = await DatabaseService.instance.database;
    final questions = await db.rawQuery('SELECT * FROM frage ORDER BY RANDOM() LIMIT 40');
    List<Map<String, dynamic>> examBuild = [];
    
    for (var q in questions) {
      if (q['typ'] == 'freitext') {
        continue; 
      }
      final answers = await db.query('antwort_option', where: 'frage_id = ?', whereArgs: [q['id']]);
      List<Map<String, dynamic>> mixedAnswers = List.from(answers)..shuffle();
      examBuild.add({'frage': q, 'antworten': mixedAnswers, 'selected_index': -1, 'is_correct': false});
    }
    if (mounted) {
      setState(() { _examData = examBuild; _isLoading = false; });
    }
  }

  void _finishExam() {
    _timer?.cancel();
    HapticFeedback.vibrate();
    int correct = _examData.where((e) => e['is_correct'] == true).length;
    double percentage = _examData.isEmpty ? 0 : (correct / _examData.length) * 100;
    
    String note = "Ungenügend";
    if (percentage >= 92) {
      note = "Sehr Gut (1)";
    } else if (percentage >= 81) {
      note = "Gut (2)";
    } else if (percentage >= 67) {
      note = "Befriedigend (3)";
    } else if (percentage >= 50) {
      note = "Ausreichend (4)";
    } else if (percentage >= 30) {
      note = "Mangelhaft (5)";
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Simulation beendet', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ergebnis: $correct von ${_examData.length} richtig.', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Text('${percentage.toStringAsFixed(1)} %', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 10),
            Text('IHK-Note: $note', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          ElevatedButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text('Zurück zum Dashboard'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    String minutes = (_timeRemaining ~/ 60).toString().padLeft(2, '0');
    String seconds = (_timeRemaining % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: Text('IHK Simulation', style: GoogleFonts.firaCode()),
        centerTitle: true,
        actions: [
          Center(child: Text('$minutes:$seconds  ', style: GoogleFonts.firaCode(fontSize: 18, color: _timeRemaining < 300 ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.bold))),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: _examData.isEmpty ? 0 : _answeredCount / _examData.length, minHeight: 6, color: Theme.of(context).colorScheme.primary),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _examData.length,
              itemBuilder: (context, index) {
                final item = _examData[index];
                final frage = item['frage'];
                final antworten = item['antworten'] as List;

                return Card(
                  margin: const EdgeInsets.only(bottom: 30),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1))),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Frage ${index + 1}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Text(frage['frage_text'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        ...antworten.asMap().entries.map((e) {
                          int aIndex = e.key;
                          var a = e.value;
                          bool isSelected = item['selected_index'] == aIndex;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  if (item['selected_index'] == -1) {
                                    _answeredCount++;
                                  }
                                  item['selected_index'] = aIndex;
                                  item['is_correct'] = (a['ist_korrekt'] == 1 || a['ist_korrekt'] == '1');
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2) : Colors.transparent,
                                  border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(a['text'].toString(), style: TextStyle(color: isSelected ? Theme.of(context).colorScheme.onSurface : Colors.grey))),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 20)),
                onPressed: _finishExam, child: const Text('Prüfung vorzeitig abgeben', style: TextStyle(fontSize: 18)),
              ),
            ),
          )
        ],
      ),
    );
  }
}