import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';

/// One logged page turn with its timestamp and (optional) word count.
class TurnSample {
  TurnSample({required this.at, this.words});
  final int at;
  final int? words;
}

class PageTurnRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<void> log({int? bookId, int? words, DateTime? at}) async {
    final db = await _db;
    await db.insert('page_turns', {
      'book_id': bookId,
      'at': (at ?? DateTime.now()).millisecondsSinceEpoch,
      'words': words,
    });
  }

  /// Returns every (timestamp, words) pair within the inclusive
  /// range [fromMs..toMs], sorted ascending by time. Used by the
  /// stats aggregator to bucket and to compute reading speed.
  Future<List<TurnSample>> samplesBetween({
    required int fromMs,
    required int toMs,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'page_turns',
      columns: ['at', 'words'],
      where: 'at >= ? AND at < ?',
      whereArgs: [fromMs, toMs],
      orderBy: 'at ASC',
    );
    return rows
        .map((r) => TurnSample(
              at: r['at'] as int,
              words: r['words'] as int?,
            ))
        .toList();
  }
}
