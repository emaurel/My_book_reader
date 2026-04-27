import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../domain/book_link.dart';

class BookLinkRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<int> add({
    required int sourceBookId,
    int? sourceChapterIndex,
    int? sourceCharStart,
    int? sourceCharEnd,
    required int targetBookId,
    required String label,
  }) async {
    final db = await _db;
    return db.insert('book_links', {
      'source_book_id': sourceBookId,
      'source_chapter_index': sourceChapterIndex,
      'source_char_start': sourceCharStart,
      'source_char_end': sourceCharEnd,
      'target_book_id': targetBookId,
      'label': label,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<BookLink>> getAll() async {
    final db = await _db;
    final rows = await db.query('book_links', orderBy: 'created_at DESC');
    return rows.map(BookLink.fromMap).toList();
  }

  /// Links that originate in the given book — used by the source
  /// book's reader / info sheet to list outbound links.
  Future<List<BookLink>> getBySourceBook(int sourceBookId) async {
    final db = await _db;
    final rows = await db.query(
      'book_links',
      where: 'source_book_id = ?',
      whereArgs: [sourceBookId],
      orderBy: 'created_at DESC',
    );
    return rows.map(BookLink.fromMap).toList();
  }

  /// Links that point at the given book — used to show "what links
  /// here" on the target.
  Future<List<BookLink>> getByTargetBook(int targetBookId) async {
    final db = await _db;
    final rows = await db.query(
      'book_links',
      where: 'target_book_id = ?',
      whereArgs: [targetBookId],
      orderBy: 'created_at DESC',
    );
    return rows.map(BookLink.fromMap).toList();
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('book_links', where: 'id = ?', whereArgs: [id]);
  }
}
