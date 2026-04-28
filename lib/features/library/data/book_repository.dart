import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../domain/book.dart';

class BookRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<List<Book>> getAll({String orderBy = 'added_at DESC'}) async {
    final db = await _db;
    final rows = await db.query('books', orderBy: orderBy);
    return rows.map(Book.fromMap).toList();
  }

  /// Books the user has started but not yet finished, sorted with the
  /// most recently opened first. Drives the "Continue reading" screen.
  Future<List<Book>> getCurrentReadings() async {
    final db = await _db;
    final rows = await db.query(
      'books',
      where: 'last_opened_at IS NOT NULL '
          'AND progress > 0 AND progress < 1',
      orderBy: 'last_opened_at DESC',
    );
    return rows.map(Book.fromMap).toList();
  }

  Future<Book?> getById(int id) async {
    final db = await _db;
    final rows = await db.query(
      'books',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Book.fromMap(rows.first);
  }

  Future<Book?> getByPath(String path) async {
    final db = await _db;
    final rows = await db.query(
      'books',
      where: 'file_path = ?',
      whereArgs: [path],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Book.fromMap(rows.first);
  }

  /// Lookup that matches either the on-disk [Book.filePath] or the
  /// pre-conversion [Book.originalPath]. Used by the device scanner so
  /// AZW3 files that have already been converted to EPUB don't get
  /// re-imported on every scan.
  Future<Book?> getBySourcePath(String path) async {
    final db = await _db;
    final rows = await db.query(
      'books',
      where: 'file_path = ? OR original_path = ?',
      whereArgs: [path, path],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Book.fromMap(rows.first);
  }

  Future<int> insert(Book book) async {
    final db = await _db;
    return db.insert(
      'books',
      book.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(Book book) async {
    if (book.id == null) {
      throw ArgumentError('Cannot update a book without an id');
    }
    final db = await _db;
    await db.update(
      'books',
      book.toMap(),
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }

  /// Books considered finished — progress at the very end. The reader
  /// formula is normalised so the last page of the last chapter lands
  /// at exactly 1.0; a tiny tolerance covers IEEE-754 rounding, but
  /// the threshold sits well above the old "near-end" trap of 0.99.
  Future<int> finishedCount() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM books WHERE progress >= 0.9995',
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  Future<List<Book>> getFinished() async {
    final db = await _db;
    final rows = await db.query(
      'books',
      where: 'progress >= ?',
      whereArgs: [0.9995],
      orderBy: 'last_opened_at DESC NULLS LAST, title COLLATE NOCASE ASC',
    );
    return rows.map(Book.fromMap).toList();
  }

  Future<void> updateProgress(
    int id, {
    required double progress,
    Map<String, dynamic>? position,
  }) async {
    final db = await _db;
    await db.update(
      'books',
      {
        'progress': progress,
        if (position != null) 'position': jsonEncode(position),
        'last_opened_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
