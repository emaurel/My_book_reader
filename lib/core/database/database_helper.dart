import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'book_reader.db';
  static const _dbVersion = 11;

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
    // Fresh DB at the latest schema. Mirrors the cumulative result of
    // every migration step in [_onUpgrade].
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
        series_number REAL,
        original_path TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_books_added_at ON books(added_at DESC)');
    await db.execute(
      'CREATE INDEX idx_books_last_opened ON books(last_opened_at DESC)',
    );

    await db.execute('''
      CREATE TABLE citations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER,
        text TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        chapter_index INTEGER,
        char_start INTEGER,
        char_end INTEGER,
        FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE SET NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_citations_created_at ON citations(created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_citations_book_chapter '
      'ON citations(book_id, chapter_index)',
    );

    await _createDictionaryTables(db);
    await _createCharacterTables(db);
  }

  Future<void> _createCharacterTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS characters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        series TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER,
        UNIQUE(name, series)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS character_descriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        character_id INTEGER NOT NULL,
        text TEXT NOT NULL,
        book_id INTEGER,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE CASCADE,
        FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE SET NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_chars_name '
      'ON characters(name COLLATE NOCASE)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_chars_series '
      'ON characters(series)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_char_descs_character '
      'ON character_descriptions(character_id)',
    );
    await _createCharacterAliasesTable(db);
    await _createAffiliationTables(db);
  }

  Future<void> _createAffiliationTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS affiliations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        series TEXT,
        created_at INTEGER NOT NULL,
        UNIQUE(name, series)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS character_affiliations (
        character_id INTEGER NOT NULL,
        affiliation_id INTEGER NOT NULL,
        PRIMARY KEY (character_id, affiliation_id),
        FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE CASCADE,
        FOREIGN KEY (affiliation_id) REFERENCES affiliations(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_affiliations_series '
      'ON affiliations(series)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_char_affs_character '
      'ON character_affiliations(character_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_char_affs_affiliation '
      'ON character_affiliations(affiliation_id)',
    );
  }

  Future<void> _createCharacterAliasesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS character_aliases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        character_id INTEGER NOT NULL,
        alias TEXT NOT NULL,
        FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE CASCADE,
        UNIQUE(character_id, alias)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_char_aliases_character '
      'ON character_aliases(character_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_char_aliases_alias '
      'ON character_aliases(alias COLLATE NOCASE)',
    );
  }

  Future<void> _createDictionaryTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dictionaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        created_at INTEGER NOT NULL,
        series TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dictionary_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dictionary_id INTEGER NOT NULL,
        word TEXT NOT NULL,
        definition TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (dictionary_id) REFERENCES dictionaries(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_dict_entries_word '
      'ON dictionary_entries(word COLLATE NOCASE)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_dict_entries_dict '
      'ON dictionary_entries(dictionary_id)',
    );
  }

  /// Migrations are idempotent — each block uses `IF NOT EXISTS` for new
  /// tables/indexes and swallows "duplicate column" errors for ALTER
  /// TABLE ADD COLUMN. This lets us recover from earlier in-progress
  /// migrations that may have partially run.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    Future<void> tryExec(String sql) async {
      try { await db.execute(sql); } catch (_) {/* already-exists, etc. */}
    }

    if (oldVersion < 2) {
      await tryExec('ALTER TABLE books ADD COLUMN description TEXT');
      await tryExec('ALTER TABLE books ADD COLUMN series TEXT');
      await tryExec('ALTER TABLE books ADD COLUMN series_number REAL');
    }
    if (oldVersion < 3) {
      await tryExec('ALTER TABLE books ADD COLUMN original_path TEXT');
    }
    if (oldVersion < 4) {
      // Create citations table in its v4 shape (no chapter columns yet —
      // those are added by the v5 migration below).
      await db.execute('''
        CREATE TABLE IF NOT EXISTS citations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          book_id INTEGER,
          text TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE SET NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_citations_created_at '
        'ON citations(created_at DESC)',
      );
    }
    if (oldVersion < 5) {
      await tryExec('ALTER TABLE citations ADD COLUMN chapter_index INTEGER');
      await tryExec('ALTER TABLE citations ADD COLUMN char_start INTEGER');
      await tryExec('ALTER TABLE citations ADD COLUMN char_end INTEGER');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_citations_book_chapter '
        'ON citations(book_id, chapter_index)',
      );
    }
    if (oldVersion < 6) {
      await _createDictionaryTables(db);
    }
    if (oldVersion < 7) {
      await tryExec('ALTER TABLE dictionaries ADD COLUMN series TEXT');
    }
    if (oldVersion < 8) {
      await _createCharacterTables(db);
    }
    if (oldVersion < 9) {
      await _createCharacterAliasesTable(db);
    }
    if (oldVersion < 10) {
      await tryExec('ALTER TABLE characters ADD COLUMN updated_at INTEGER');
      // Backfill so existing characters have a sensible last-modified
      // timestamp matching their creation date.
      await db.execute(
        'UPDATE characters SET updated_at = created_at '
        'WHERE updated_at IS NULL',
      );
    }
    if (oldVersion < 11) {
      await _createAffiliationTables(db);
    }
  }
}
