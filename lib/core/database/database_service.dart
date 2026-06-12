import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {

  DatabaseService._();

  static final DatabaseService instance =
      DatabaseService._();

  Database? _database;

  Future<Database> get database async {

    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();

    return _database!;
  }

  Future<Database> _initDatabase() async {

    final path = join(
      await getDatabasesPath(),
      "fachinformatiker.db",
    );

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {

        print("DB erstellt");

      },
    );
  }
}