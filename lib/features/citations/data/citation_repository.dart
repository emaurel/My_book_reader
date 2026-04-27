import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../domain/citation.dart';

class CitationRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<int> add({
    int? bookId,
    required String text,
    int? chapterIndex,
    int? charStart,
    int? charEnd,
  }) async {
    final db = await _db;
    return db.insert('citations', {
      'book_id': bookId,
      'text': text,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'chapter_index': chapterIndex,
      'char_start': charStart,
      'char_end': charEnd,
    });
  }

  Future<List<Citation>> getAll() async {
    final db = await _db;
    final rows = await db.query('citations', orderBy: 'created_at DESC');
    return rows.map(Citation.fromMap).toList();
  }

  Future<Citation?> getById(int id) async {
    final db = await _db;
    final rows = await db.query(
      'citations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Citation.fromMap(rows.first);
  }

  /// Citations attached to a specific chapter of a specific book — used
  /// by the EPUB reader on chapter render to re-paint persistent
  /// highlights.
  Future<List<Citation>> getByBookAndChapter(int bookId, int chapterIndex) async {
    final db = await _db;
    final rows = await db.query(
      'citations',
      where: 'book_id = ? AND chapter_index = ? '
          'AND char_start IS NOT NULL AND char_end IS NOT NULL',
      whereArgs: [bookId, chapterIndex],
      orderBy: 'char_start ASC',
    );
    return rows.map(Citation.fromMap).toList();
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('citations', where: 'id = ?', whereArgs: [id]);
  }
}
