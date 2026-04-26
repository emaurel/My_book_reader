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
