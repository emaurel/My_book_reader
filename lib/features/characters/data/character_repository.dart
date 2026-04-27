import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../domain/character.dart';
import '../domain/character_description.dart';

class CharacterRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  /// Bump `characters.updated_at` so the character moves to the top of
  /// "by last modified" sorts. Called after every description / alias
  /// mutation. Safe to call with a non-existent id (no-op).
  Future<void> _touchCharacter(int characterId) async {
    final db = await _db;
    await db.update(
      'characters',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [characterId],
    );
  }

  static const _orderClause =
      'COALESCE(updated_at, created_at) DESC, name COLLATE NOCASE ASC';

  // ---- Characters ----

  Future<List<Character>> listAll() async {
    final db = await _db;
    final rows = await db.query('characters', orderBy: _orderClause);
    return rows.map(Character.fromMap).toList();
  }

  /// Characters that apply to a book in [series]: global characters
  /// (`series IS NULL`) plus any whose series matches. Ordered by
  /// last-modified first so recently-touched names surface in the
  /// add-description picker.
  Future<List<Character>> listForSeries(String? series) async {
    final db = await _db;
    final List<Map<String, Object?>> rows;
    if (series == null) {
      rows = await db.query(
        'characters',
        where: 'series IS NULL',
        orderBy: _orderClause,
      );
    } else {
      rows = await db.query(
        'characters',
        where: 'series IS NULL OR series = ?',
        whereArgs: [series],
        orderBy: _orderClause,
      );
    }
    return rows.map(Character.fromMap).toList();
  }

  Future<int> create({required String name, String? series}) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.insert('characters', {
      'name': name,
      'series': series,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('characters', where: 'id = ?', whereArgs: [id]);
  }

  Future<Character?> findByName(String name, {String? series}) async {
    final db = await _db;
    final List<Map<String, Object?>> rows;
    if (series == null) {
      rows = await db.query(
        'characters',
        where: 'name = ? COLLATE NOCASE AND series IS NULL',
        whereArgs: [name],
        limit: 1,
      );
    } else {
      rows = await db.query(
        'characters',
        where: 'name = ? COLLATE NOCASE AND (series IS NULL OR series = ?)',
        whereArgs: [name, series],
        limit: 1,
      );
    }
    if (rows.isEmpty) return null;
    return Character.fromMap(rows.first);
  }

  // ---- Descriptions ----

  Future<int> addDescription({
    required int characterId,
    required String text,
    int? bookId,
  }) async {
    final db = await _db;
    final id = await db.insert('character_descriptions', {
      'character_id': characterId,
      'text': text,
      'book_id': bookId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    await _touchCharacter(characterId);
    return id;
  }

  Future<void> updateDescription({
    required int id,
    required String text,
  }) async {
    final db = await _db;
    await db.update(
      'character_descriptions',
      {'text': text},
      where: 'id = ?',
      whereArgs: [id],
    );
    final rows = await db.query(
      'character_descriptions',
      columns: ['character_id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      await _touchCharacter(rows.first['character_id'] as int);
    }
  }

  Future<void> deleteDescription(int id) async {
    final db = await _db;
    final rows = await db.query(
      'character_descriptions',
      columns: ['character_id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    await db.delete('character_descriptions', where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      await _touchCharacter(rows.first['character_id'] as int);
    }
  }

  Future<List<CharacterDescription>> descriptionsForCharacter(
    int characterId,
  ) async {
    final db = await _db;
    final rows = await db.query(
      'character_descriptions',
      where: 'character_id = ?',
      whereArgs: [characterId],
      orderBy: 'created_at ASC',
    );
    return rows.map(CharacterDescription.fromMap).toList();
  }

  // ---- Aliases ----

  Future<List<String>> aliasesForCharacter(int characterId) async {
    final db = await _db;
    final rows = await db.query(
      'character_aliases',
      where: 'character_id = ?',
      whereArgs: [characterId],
      orderBy: 'alias COLLATE NOCASE ASC',
    );
    return rows.map((r) => r['alias'] as String).toList();
  }

  Future<int> addAlias({required int characterId, required String alias}) async {
    final db = await _db;
    final id = await db.insert(
      'character_aliases',
      {'character_id': characterId, 'alias': alias},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await _touchCharacter(characterId);
    return id;
  }

  Future<void> deleteAlias({required int characterId, required String alias}) async {
    final db = await _db;
    await db.delete(
      'character_aliases',
      where: 'character_id = ? AND alias = ? COLLATE NOCASE',
      whereArgs: [characterId, alias],
    );
    await _touchCharacter(characterId);
  }

  /// Map of character_id → list of aliases for the given series scope.
  /// Used by the EPUB viewer to compose the regex with each character's
  /// canonical name plus all their aliases.
  Future<Map<int, List<String>>> aliasesByCharacter(String? series) async {
    final db = await _db;
    final List<Map<String, Object?>> rows;
    if (series == null) {
      rows = await db.rawQuery('''
        SELECT a.character_id, a.alias FROM character_aliases a
        JOIN characters c ON c.id = a.character_id
        WHERE c.series IS NULL
      ''');
    } else {
      rows = await db.rawQuery('''
        SELECT a.character_id, a.alias FROM character_aliases a
        JOIN characters c ON c.id = a.character_id
        WHERE c.series IS NULL OR c.series = ?
      ''', [series]);
    }
    final out = <int, List<String>>{};
    for (final r in rows) {
      final id = r['character_id'] as int;
      final alias = r['alias'] as String;
      (out[id] ??= []).add(alias);
    }
    return out;
  }

  /// Find a character by name OR alias. Used when the user taps an
  /// underlined token in the reader so we can identify which character
  /// it belongs to.
  Future<Character?> findByNameOrAlias(
    String name, {
    String? series,
  }) async {
    final db = await _db;
    final List<Map<String, Object?>> rows;
    if (series == null) {
      rows = await db.rawQuery('''
        SELECT DISTINCT c.* FROM characters c
        LEFT JOIN character_aliases a ON a.character_id = c.id
        WHERE c.series IS NULL
          AND (c.name = ? COLLATE NOCASE OR a.alias = ? COLLATE NOCASE)
        LIMIT 1
      ''', [name, name]);
    } else {
      rows = await db.rawQuery('''
        SELECT DISTINCT c.* FROM characters c
        LEFT JOIN character_aliases a ON a.character_id = c.id
        WHERE (c.series IS NULL OR c.series = ?)
          AND (c.name = ? COLLATE NOCASE OR a.alias = ? COLLATE NOCASE)
        LIMIT 1
      ''', [series, name, name]);
    }
    if (rows.isEmpty) return null;
    return Character.fromMap(rows.first);
  }
}
