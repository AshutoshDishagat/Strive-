import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/session.dart';

class DatabaseHelper {
  static Database? _database;
  static final DatabaseHelper instance = DatabaseHelper._();

  DatabaseHelper._();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String p = join(await getDatabasesPath(), 'strive_sessions.db');
    return await openDatabase(
      p,
      version: 4, // onUpgrade
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE sessions(id INTEGER PRIMARY KEY AUTOINCREMENT, user_id TEXT, start_time TEXT, duration_seconds INTEGER, engagement_score REAL, study_mode TEXT)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE sessions ADD COLUMN user_id TEXT');
          } catch (_) {}
        }
        if (oldVersion < 3) {
          try {
            await db.execute('ALTER TABLE sessions ADD COLUMN study_mode TEXT');
          } catch (_) {}
        }
        if (oldVersion < 4) {
          // version
          try {
            await db.execute('ALTER TABLE sessions ADD COLUMN study_mode TEXT');
          } catch (_) {}
        }
      },
    );
  }

  Future<void> insertSession(Session session) async {
    final db = await database;
    await db.insert(
      'sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Session>> getSessions(String? userId) async {
    final db = await database;

    if (userId == null) {
      // Not logged in — return all sessions
      final List<Map<String, dynamic>> maps = await db.query(
        'sessions',
        orderBy: 'start_time DESC',
      );
      return List.generate(maps.length, (i) => Session.fromMap(maps[i]));
    }

    // Return sessions for this user OR legacy sessions with no user_id
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      "SELECT * FROM sessions WHERE user_id = ? OR user_id IS NULL OR user_id = '' ORDER BY start_time DESC",
      [userId],
    );

    return List.generate(maps.length, (i) => Session.fromMap(maps[i]));
  }
}
