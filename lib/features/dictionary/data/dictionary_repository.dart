import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../domain/dictionary.dart';
import '../domain/dictionary_entry.dart';

class DictionaryRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  // ---- Dictionaries ----

  Future<List<Dictionary>> listDictionaries() async {
    final db = await _db;
    final rows = await db.query(
      'dictionaries',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Dictionary.fromMap).toList();
  }

  Future<int> createDictionary({
    required String name,
    String? description,
    String? series,
  }) async {
    final db = await _db;
    return db.insert('dictionaries', {
      'name': name,
      'description': description,
      'series': series,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deleteDictionary(int id) async {
    final db = await _db;
    await db.delete('dictionaries', where: 'id = ?', whereArgs: [id]);
  }

  // ---- Entries ----

  Future<int> addEntry({
    required int dictionaryId,
    required String word,
    required String definition,
  }) async {
    final db = await _db;
    return db.insert('dictionary_entries', {
      'dictionary_id': dictionaryId,
      'word': word,
      'definition': definition,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updateEntry({
    required int id,
    required String definition,
  }) async {
    final db = await _db;
    await db.update(
      'dictionary_entries',
      {'definition': definition},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteEntry(int id) async {
    final db = await _db;
    await db.delete('dictionary_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<DictionaryEntry>> entriesForDictionary(int dictionaryId) async {
    final db = await _db;
    final rows = await db.query(
      'dictionary_entries',
      where: 'dictionary_id = ?',
      whereArgs: [dictionaryId],
      orderBy: 'word COLLATE NOCASE ASC',
    );
    return rows.map(DictionaryEntry.fromMap).toList();
  }

  /// Distinct words from dictionaries that apply to a book in [series]:
  /// global dictionaries (`d.series IS NULL`) plus any whose series
  /// matches. Pass `series = null` for a book without a series and you
  /// get only the globals.
  Future<List<String>> wordsForSeries(String? series) async {
    final db = await _db;
    final List<Map<String, Object?>> rows;
    if (series == null) {
      rows = await db.rawQuery('''
        SELECT DISTINCT e.word FROM dictionary_entries e
        JOIN dictionaries d ON d.id = e.dictionary_id
        WHERE d.series IS NULL
      ''');
    } else {
      rows = await db.rawQuery('''
        SELECT DISTINCT e.word FROM dictionary_entries e
        JOIN dictionaries d ON d.id = e.dictionary_id
        WHERE d.series IS NULL OR d.series = ?
      ''', [series]);
    }
    return rows.map((r) => r['word'] as String).toList();
  }

  /// Entries (joined with their dictionary) whose word matches
  /// case-insensitively, restricted to dictionaries that apply in the
  /// given [series] context (global + matching).
  Future<List<DictionaryEntry>> entriesForWord(
    String word, {
    String? series,
  }) async {
    final db = await _db;
    final List<Map<String, Object?>> rows;
    if (series == null) {
      rows = await db.rawQuery('''
        SELECT e.* FROM dictionary_entries e
        JOIN dictionaries d ON d.id = e.dictionary_id
        WHERE e.word = ? COLLATE NOCASE AND d.series IS NULL
        ORDER BY e.created_at ASC
      ''', [word]);
    } else {
      rows = await db.rawQuery('''
        SELECT e.* FROM dictionary_entries e
        JOIN dictionaries d ON d.id = e.dictionary_id
        WHERE e.word = ? COLLATE NOCASE
          AND (d.series IS NULL OR d.series = ?)
        ORDER BY e.created_at ASC
      ''', [word, series]);
    }
    return rows.map(DictionaryEntry.fromMap).toList();
  }
}
