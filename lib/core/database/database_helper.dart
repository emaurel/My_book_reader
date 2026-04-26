import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'book_reader.db';
  static const _dbVersion = 2;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author TEXT,
        file_path TEXT NOT NULL UNIQUE,
        format TEXT NOT NULL,
        cover_path TEXT,
        file_size INTEGER,
        added_at INTEGER NOT NULL,
        last_opened_at INTEGER,
        progress REAL NOT NULL DEFAULT 0,
        position TEXT,
        description TEXT,
        series TEXT,
        series_number REAL
      )
    ''');

    await db.execute('CREATE INDEX idx_books_added_at ON books(added_at DESC)');
    await db.execute(
      'CREATE INDEX idx_books_last_opened ON books(last_opened_at DESC)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE books ADD COLUMN description TEXT');
      await db.execute('ALTER TABLE books ADD COLUMN series TEXT');
      await db.execute('ALTER TABLE books ADD COLUMN series_number REAL');
    }
  }
}
