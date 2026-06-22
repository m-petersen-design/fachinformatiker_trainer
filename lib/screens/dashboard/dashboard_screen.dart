import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/database/database_service.dart';
import '../../models/fachrichtung.dart';
import '../themen/themen_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../profile/profile_screen.dart';

// ==========================================
// SCI-FI: PARALLAX STARFIELD BACKGROUND
// ==========================================
class StarfieldPainter extends CustomPainter {
  final double animationValue;
  final math.Random random = math.Random(42); // Fester Seed für stabile Sterne

  StarfieldPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.3);
    for (int i = 0; i < 150; i++) {
      double x = random.nextDouble() * size.width;
      double yOffset = random.nextDouble() * size.height;
      double speed = random.nextDouble() * 2 + 0.5; // Verschiedene Tiefen
      double sizeDot = random.nextDouble() * 2;
      
      // Sterne wandern langsam nach unten
      double y = (yOffset + (animationValue * 1000 * speed)) % size.height;
      canvas.drawCircle(Offset(x, y), sizeDot, paint..color = Colors.white.withValues(alpha: speed / 3));
    }
  }
  @override
  bool shouldRepaint(covariant StarfieldPainter oldDelegate) => oldDelegate.animationValue != animationValue;
}

// ==========================================
// SCI-FI: HYPERSPACE LOADER
// ==========================================
class HyperspaceLoader extends StatelessWidget {
  const HyperspaceLoader({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.5, end: 2.0),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutBack,
        builder: (context, val, child) {
          return Transform.scale(
            scale: val,
            child: Icon(Icons.blur_on, color: Theme.of(context).colorScheme.primary.withValues(alpha: 1.0 - (val / 2)), size: 60),
          );
        },
      ),
    );
  }
}

// ==========================================
// HAPTIK: BOUNCE CARD FÜR KLICKS
// ==========================================
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  List<Fachrichtung> _fachrichtungen = [];
  bool _isLoading = true;
  int _globalXP = 0;
  int _aktuellerTagStreak = 0;

  late AnimationController _pulseController;
  late AnimationController _starController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _starController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _ladeDaten();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _starController.dispose();
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
        id: maps[i]['id'] as int, name: maps[i]['name'] as String,
        kuerzel: maps[i]['kuerzel'] as String, beschreibung: maps[i]['beschreibung']?.toString() ?? '',
        farbeHex: maps[i]['farbe_hex']?.toString() ?? '#00E5FF', xp: xp,
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
        // GLASSMORPHISMUS
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
              ),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 60, height: 60,
                        // ANIMIERTER BALKEN
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: progressValue),
                          duration: const Duration(seconds: 1),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) => CircularProgressIndicator(
                            value: value, strokeWidth: 5, color: Theme.of(context).colorScheme.primary,
                            backgroundColor: Colors.white10, strokeCap: StrokeCap.round,
                          ),
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
                        scale: _aktuellerTagStreak > 0 ? Tween<double>(begin: 1.0, end: 1.2).animate(_pulseController) : const AlwaysStoppedAnimation(1.0),
                        child: Icon(Icons.local_fire_department, color: Theme.of(context).colorScheme.primary, size: 36),
                      ),
                      const SizedBox(height: 4),
                      Text('$_aktuellerTagStreak Tage', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSleekFachrichtungCard(Fachrichtung fach) {
    Color accentColor = Color(int.parse(fach.farbeHex.replaceAll('#', '0xFF')));

    return BounceCard(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (context) => ThemenScreen(fachrichtung: fach)));
        _ladeDaten(); 
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
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
                        // HERO ANIMATION!
                        Hero(
                          tag: 'fach_banner_${fach.id}',
                          child: Material(
                            type: MaterialType.transparency,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: accentColor, width: 1.5),
                              ),
                              child: Text(fach.kuerzel, style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1)),
                            ),
                          ),
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
                            // ANIMIERTE PROGRESS BAR
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.0, end: (fach.xp % 100) / 100),
                              duration: const Duration(seconds: 1),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, _) => LinearProgressIndicator(
                                value: value, minHeight: 12, color: accentColor, backgroundColor: Colors.white10,
                              ),
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
          // STARFIELD BACKGROUND
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _starController,
                builder: (context, child) => CustomPaint(painter: StarfieldPainter(_starController.value)),
              ),
            ),
          ),
          if (_isLoading)
            const HyperspaceLoader() // NEUER LOADER
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