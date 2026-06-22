import 'package:flutter/material.dart';
import '../../core/database/database_service.dart';
import '../../models/fachrichtung.dart';
import '../themen/themen_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../profile/profile_screen.dart';

// Eigener Painter für den Terminal-Scanline-Look
class ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;
    for (double i = 0; i < size.height; i += 4) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  List<Fachrichtung> _fachrichtungen = [];
  bool _isLoading = true;
  int _globalXP = 0;
  int _aktuellerTagStreak = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Puls-Animation (Atmen) für die Flamme einrichten
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    
    _ladeDaten();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _ladeDaten() async {
    final db = await DatabaseService.instance.database;
    final List<Map<String, dynamic>> maps = await db.query('fachrichtung');
    int berechneteGesamtXp = 0; 
    
    final rawFachrichtungen = List.generate(maps.length, (i) {
      final xp = maps[i]['xp'] as int? ?? 0;
      berechneteGesamtXp += xp; 
      return Fachrichtung(
        id: maps[i]['id'] as int,
        name: maps[i]['name'] as String,
        kuerzel: maps[i]['kuerzel'] as String,
        beschreibung: maps[i]['beschreibung']?.toString() ?? '',
        farbeHex: maps[i]['farbe_hex']?.toString() ?? '#00E5FF',
        xp: xp,
      );
    });

    final userStats = await db.query('user_stats', where: 'id = 1');
    int streak = 0;
    if (userStats.isNotEmpty) streak = userStats.first['streak_tage'] as int;

    setState(() {
      _fachrichtungen = rawFachrichtungen;
      _globalXP = berechneteGesamtXp; 
      _aktuellerTagStreak = streak;
      _isLoading = false;
    });
  }

  Widget _buildModernGlobalHUD() {
    double progressValue = (_globalXP % 500) / 500.0;
    if (_globalXP > 0 && progressValue == 0) progressValue = 1.0;

    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
        _ladeDaten(); 
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 60, height: 60,
                  child: CircularProgressIndicator(
                    value: progressValue, 
                    strokeWidth: 5,
                    color: Theme.of(context).colorScheme.primary,
                    backgroundColor: Colors.white10,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Icon(Icons.star, color: Theme.of(context).colorScheme.primary, size: 28),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gesamt XP', style: Theme.of(context).textTheme.bodyMedium),
                  Text('$_globalXP', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 30, color: Theme.of(context).colorScheme.primary)),
                ],
              ),
            ),
            Column(
              children: [
                ScaleTransition(
                  scale: _aktuellerTagStreak > 0 ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                  child: Icon(Icons.local_fire_department, color: Theme.of(context).colorScheme.primary, size: 36),
                ),
                const SizedBox(height: 4),
                Text('$_aktuellerTagStreak Tage', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleekFachrichtungCard(Fachrichtung fach) {
    Color accentColor = Color(int.parse(fach.farbeHex.replaceAll('#', '0xFF')));

    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (context) => ThemenScreen(fachrichtung: fach)));
        _ladeDaten(); 
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [const Color(0xFF1D2229), accentColor.withValues(alpha: 0.15)],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: accentColor, width: 1.5),
                          ),
                          child: Text(fach.kuerzel, style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1)),
                        ),
                        Text('⭐ ${fach.xp} XP', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(fach.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24, letterSpacing: -0.5)),
                    const SizedBox(height: 10),
                    Text(fach.beschreibung, style: Theme.of(context).textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Text('Level 1', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: LinearProgressIndicator(
                              value: (fach.xp % 100) / 100, 
                              minHeight: 12, color: accentColor, backgroundColor: Colors.white10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('${100 - (fach.xp % 100)} XP to go', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
              _ladeDaten(); 
            }, 
            icon: Icon(Icons.settings, color: Theme.of(context).colorScheme.primary),
            tooltip: 'Creator Mode',
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Stack(
        children: [
          Container(color: Theme.of(context).scaffoldBackgroundColor),
          Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: ScanlinePainter())),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            ListView(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 30),
              children: [
                _buildModernGlobalHUD(),
                const Padding(
                  padding: EdgeInsets.only(left: 20.0, top: 30.0, bottom: 20.0),
                  child: Text('Fachrichtungen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.1)),
                ),
                ..._fachrichtungen.map((fach) => _buildSleekFachrichtungCard(fach)),
              ],
            ),
        ],
      ),
    );
  }
}