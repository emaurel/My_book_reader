import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../domain/note.dart';

class NoteRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<int> add({
    int? bookId,
    int? chapterIndex,
    int? charStart,
    int? charEnd,
    required String selectedText,
    required String noteText,
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.insert('notes', {
      'book_id': bookId,
      'chapter_index': chapterIndex,
      'char_start': charStart,
      'char_end': charEnd,
      'selected_text': selectedText,
      'note_text': noteText,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<List<Note>> getAll() async {
    final db = await _db;
    final rows = await db.query('notes', orderBy: 'updated_at DESC');
    return rows.map(Note.fromMap).toList();
  }

  Future<Note?> getById(int id) async {
    final db = await _db;
    final rows = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Note.fromMap(rows.first);
  }

  /// Notes in a specific chapter — used by the reader to re-paint the
  /// inline note underline / handle taps.
  Future<List<Note>> getByBookAndChapter(
    int bookId,
    int chapterIndex,
  ) async {
    final db = await _db;
    final rows = await db.query(
      'notes',
      where: 'book_id = ? AND chapter_index = ? '
          'AND char_start IS NOT NULL AND char_end IS NOT NULL',
      whereArgs: [bookId, chapterIndex],
      orderBy: 'char_start ASC',
    );
    return rows.map(Note.fromMap).toList();
  }

  Future<void> updateText(int id, String noteText) async {
    final db = await _db;
    await db.update(
      'notes',
      {
        'note_text': noteText,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }
}
