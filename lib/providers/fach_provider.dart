import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/fachrichtung.dart';
import '../models/themengebiet.dart';
import '../repositories/fach_repository.dart';

final fachRepositoryProvider = Provider((ref) => FachRepository());

final fachrichtungenProvider = FutureProvider<List<Fachrichtung>>((ref) async {
  final repo = ref.read(fachRepositoryProvider);
  return repo.getFachrichtungen();
});

// WICHTIG: String wurde zu int (fachrichtungId)
final themengebieteProvider = FutureProvider.family<List<Themengebiet>, int>((ref, fachrichtungId) async {
  final repo = ref.read(fachRepositoryProvider);
  return repo.getThemengebiete(fachrichtungId);
});