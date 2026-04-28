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

  /// Cumulative pages and words across every logged turn ever.
  Future<({int pages, int words})> allTimeTotals() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS pages, COALESCE(SUM(words), 0) AS words '
      'FROM page_turns',
    );
    final r = rows.first;
    return (
      pages: (r['pages'] as int?) ?? 0,
      words: (r['words'] as int?) ?? 0,
    );
  }

  /// Earliest logged turn, or null if there's never been one. Used
  /// by the all-time view to bound how far back month-paging goes.
  Future<DateTime?> earliestTurn() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT MIN(at) AS at FROM page_turns',
    );
    final at = rows.first['at'];
    if (at is! int) return null;
    return DateTime.fromMillisecondsSinceEpoch(at);
  }
}
