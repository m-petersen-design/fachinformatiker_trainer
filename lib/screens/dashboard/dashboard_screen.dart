import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart'; 
import '../../core/database/database_service.dart';
import '../../models/fachrichtung.dart';
import '../themen/themen_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../profile/profile_screen.dart';
import '../extras/lern_tools.dart'; 

class StarfieldPainter extends CustomPainter {
  final double animationValue;
  final math.Random random = math.Random(42); 
  final Color starColor;

  StarfieldPainter(this.animationValue, this.starColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = starColor.withValues(alpha: 0.3);
    for (int i = 0; i < 150; i++) {
      double x = random.nextDouble() * size.width;
      double yOffset = random.nextDouble() * size.height;
      double speed = random.nextDouble() * 2 + 0.5; 
      double sizeDot = random.nextDouble() * 2;
      double y = (yOffset + (animationValue * 1000 * speed)) % size.height;
      canvas.drawCircle(Offset(x, y), sizeDot, paint..color = starColor.withValues(alpha: speed / 3));
    }
  }
  @override
  bool shouldRepaint(covariant StarfieldPainter oldDelegate) => oldDelegate.animationValue != animationValue;
}

class HyperspaceLoader extends StatelessWidget {
  const HyperspaceLoader({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.5, end: 2.0),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutBack,
        builder: (context, val, child) => Transform.scale(
          scale: val,
          child: Icon(Icons.blur_on, color: Theme.of(context).colorScheme.primary.withValues(alpha: 1.0 - (val / 2)), size: 60),
        ),
      ),
    );
  }
}

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
      onTapUp: (_) { 
        HapticFeedback.lightImpact(); 
        _controller.reverse(); 
        widget.onTap(); 
      },
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
  bool _showVaderGreeting = false;

  int _questProgress = 0;
  final int _questGoal = 10;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _starController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _ladeDaten();
    _loadDailyQuests();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _showVaderGreeting = true);
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _showVaderGreeting = false);
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _starController.dispose();
    super.dispose();
  }

  Future<void> _loadDailyQuests() async {
    final prefs = await SharedPreferences.getInstance();
    String today = DateTime.now().toIso8601String().substring(0, 10);
    String savedDate = prefs.getString('questDate') ?? '';
    
    if (savedDate != today) {
      await prefs.setString('questDate', today);
      await prefs.setInt('questFragen', 0);
    }
    setState(() { _questProgress = prefs.getInt('questFragen') ?? 0; });
  }

  Future<void> _ladeDaten() async {
    final db = await DatabaseService.instance.database;
    final List<Map<String, dynamic>> maps = await db.query('fachrichtung');
    int berechneteGesamtXp = 0; 
    
    final rawFachrichtungen = List.generate(maps.length, (i) {
      final xp = maps[i]['xp'] as int? ?? 0;
      berechneteGesamtXp += xp; 
      return Fachrichtung(
        id: maps[i]['id'] as int, name: maps[i]['name'] as String, kuerzel: maps[i]['kuerzel'] as String, 
        beschreibung: maps[i]['beschreibung']?.toString() ?? '', farbeHex: maps[i]['farbe_hex']?.toString() ?? '#00E5FF', xp: xp,
      );
    });

    final userStats = await db.query('user_stats', where: 'id = 1');
    int streak = 0;
    if (userStats.isNotEmpty) streak = userStats.first['streak_tage'] as int;

    setState(() {
      _fachrichtungen = rawFachrichtungen; _globalXP = berechneteGesamtXp; 
      _aktuellerTagStreak = streak; _isLoading = false;
    });
  }

  void _toggleTheme() async {
    HapticFeedback.selectionClick();
    final prefs = await SharedPreferences.getInstance();
    bool isCurrentlyJedi = themeNotifier.value == ThemeMode.light;
    themeNotifier.value = isCurrentlyJedi ? ThemeMode.dark : ThemeMode.light;
    await prefs.setBool('isJedi', !isCurrentlyJedi);
  }

  Widget _buildDailyQuestCard() {
    double progress = (_questProgress / _questGoal).clamp(0.0, 1.0);
    bool isDone = _questProgress >= _questGoal;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDone ? Colors.greenAccent : Theme.of(context).colorScheme.primary.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isDone ? Icons.military_tech : Icons.explore, color: isDone ? Colors.greenAccent : Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text('Tägliche Mission', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 12),
          Text('Beantworte 10 Fragen, um deine Fähigkeiten zu schärfen.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: progress, minHeight: 10,
                    color: isDone ? Colors.greenAccent : Theme.of(context).colorScheme.primary,
                    backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('$_questProgress / $_questGoal', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildZusatzModuleLeiste() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20.0, top: 20.0, bottom: 10.0),
          child: Text('Zusatz-Module', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), letterSpacing: 1.1)),
        ),
        SizedBox(
          height: 140,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildToolCard('Holocron\nArchiv', Icons.bookmark, Colors.amber, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HolocronScreen()))),
              _buildToolCard('Flash\nCards', Icons.style, Colors.purpleAccent, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FlashcardScreen()))),
              _buildToolCard('IHK\nSimulation', Icons.timer, Colors.redAccent, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ExamScreen()))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return BounceCard(
      onTap: onTap,
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 12, bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 32),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, height: 1.2)),
          ],
        ),
      ),
    );
  }

  Widget _buildModernGlobalHUD() {
    double progressValue = (_globalXP % 500) / 500.0;
    if (_globalXP > 0 && progressValue == 0) progressValue = 1.0;

    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        await Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
        _ladeDaten(); _loadDailyQuests();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1), width: 1.5),
              ),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 60, height: 60,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: progressValue),
                          duration: const Duration(seconds: 1), curve: Curves.easeOutCubic,
                          builder: (context, value, _) => CircularProgressIndicator(value: value, strokeWidth: 5, color: Theme.of(context).colorScheme.primary, backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1), strokeCap: StrokeCap.round),
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
                      Text('$_aktuellerTagStreak Tage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
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
        _ladeDaten(); _loadDailyQuests();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 8))],
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
                      colors: [Theme.of(context).cardColor, accentColor.withValues(alpha: 0.15)],
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
                        Hero(
                          tag: 'fach_banner_${fach.id}',
                          child: Material(
                            type: MaterialType.transparency,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(100), border: Border.all(color: accentColor, width: 1.5)),
                              child: Text(fach.kuerzel, style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1)),
                            ),
                          ),
                        ),
                        Text('⭐ ${fach.xp} XP', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(fach.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24, letterSpacing: -0.5, color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 10),
                    Text(fach.beschreibung, style: Theme.of(context).textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text('Level 1', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.0, end: (fach.xp % 100) / 100), duration: const Duration(seconds: 1), curve: Curves.easeOutCubic,
                              builder: (context, value, _) => LinearProgressIndicator(value: value, minHeight: 12, color: accentColor, backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('${100 - (fach.xp % 100)} XP to go', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13)),
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
    bool isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        actions: [
          IconButton(onPressed: _toggleTheme, icon: Icon(isLight ? Icons.dark_mode : Icons.light_mode, color: Theme.of(context).colorScheme.primary), tooltip: 'Wähle deine Seite'),
          IconButton(
            onPressed: () async {
              HapticFeedback.selectionClick();
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
              _ladeDaten(); _loadDailyQuests();
            }, 
            icon: Icon(Icons.settings, color: Theme.of(context).colorScheme.primary), tooltip: 'Creator Mode',
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Stack(
        children: [
          Container(color: Theme.of(context).scaffoldBackgroundColor),
          Positioned.fill(child: IgnorePointer(child: AnimatedBuilder(animation: _starController, builder: (context, child) => CustomPaint(painter: StarfieldPainter(_starController.value, Theme.of(context).colorScheme.onSurface))))),
          if (_isLoading)
            const HyperspaceLoader()
          else
            ListView(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 30),
              children: [
                _buildModernGlobalHUD(),
                _buildDailyQuestCard(),
                _buildZusatzModuleLeiste(),
                Padding(
                  padding: const EdgeInsets.only(left: 20.0, top: 20.0, bottom: 10.0),
                  child: Text('Fachrichtungen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), letterSpacing: 1.1)),
                ),
                ..._fachrichtungen.map((fach) => _buildSleekFachrichtungCard(fach)),
              ],
            ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            top: _showVaderGreeting ? MediaQuery.of(context).padding.top + 10 : -150, 
            left: 20, right: 20,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                  boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3), blurRadius: 15, spreadRadius: 2)],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      // GROSSES HALLO-GIF: 120x120
                      child: Image.asset('assets/vader_hallo.gif', width: 120, height: 120, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Icon(Icons.person, color: Theme.of(context).colorScheme.onSurface, size: 60)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Lord Vader', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('Hallo. Das Training wartet auf dich.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontStyle: FontStyle.italic)),
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
}