import '../core/database/database_service.dart';
import '../models/fachrichtung.dart';
import '../models/themengebiet.dart';

class FachRepository {
  Future<List<Fachrichtung>> getFachrichtungen() async {
    final db = await DatabaseService.instance.database;
    final List<Map<String, dynamic>> maps = await db.query('fachrichtung'); // Name angepasst
    
    return List.generate(maps.length, (i) => Fachrichtung.fromMap(maps[i]));
  }

  // Suchen jetzt nach der ID, nicht mehr nach dem Kürzel
  Future<List<Themengebiet>> getThemengebiete(int fachrichtungId) async {
    final db = await DatabaseService.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'themengebiet', // Name angepasst
      where: 'fachrichtung_id = ?',
      whereArgs: [fachrichtungId],
    );
    
    return List.generate(maps.length, (i) => Themengebiet.fromMap(maps[i]));
  }
}