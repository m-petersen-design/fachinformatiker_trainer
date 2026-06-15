import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // <-- NEU
import 'screens/dashboard/dashboard_screen.dart';
import 'core/database/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.database;

  // WICHTIG: ProviderScope umhüllt die App
  runApp(
    const ProviderScope(
      child: FachinformatikerTrainer(),
    ),
  );
}

class FachinformatikerTrainer extends StatelessWidget {
  const FachinformatikerTrainer({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fachinformatiker Trainer',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
      ),
      home: const DashboardScreen(),
    );
  }
}