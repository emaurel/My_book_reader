import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/page_turn_repository.dart';
import '../domain/stats.dart';

const _idleGapMinutes = 5;

final pageTurnRepositoryProvider =
    Provider<PageTurnRepository>((_) => PageTurnRepository());

/// Aggregate stats for the requested [StatsRange]:
///   * [StatsRange.day] — hourly buckets for the last 24 hours, ending
///     at the current hour.
///   * [StatsRange.week] — daily buckets for the last 7 days.
///   * [StatsRange.month] — daily buckets for the last 30 days.
final readingStatsProvider = FutureProvider.autoDispose
    .family<ReadingStats, StatsRange>((ref, range) async {
  final repo = ref.watch(pageTurnRepositoryProvider);
  final now = DateTime.now();
  final (fromMs, buckets) = _bucketsFor(range, now);
  final samples = await repo.samplesBetween(
    fromMs: fromMs,
    toMs: now.millisecondsSinceEpoch,
  );

  // Bucket pages + sum words.
  var totalWords = 0;
  for (final s in samples) {
    final dt = DateTime.fromMillisecondsSinceEpoch(s.at);
    final i = _bucketIndexFor(range, dt, now);
    if (i >= 0 && i < buckets.length) {
      buckets[i] = ReadingBucket(
        label: buckets[i].label,
        pages: buckets[i].pages + 1,
      );
    }
    totalWords += s.words ?? 0;
  }

  // Fully-measured pages: the gap between samples[i-1] and samples[i]
  // is time spent reading samples[i-1]'s page, but only when that gap
  // is under the idle threshold. The first sample of a session has
  // no prior anchor, the last has no following one — so N samples
  // yield at most N-1 measured pages, not N. Using the right count
  // keeps pages-per-hour from inflating after a single turn.
  var activeMs = 0;
  var measuredPages = 0;
  var measuredWords = 0;
  const idleMs = _idleGapMinutes * 60 * 1000;
  for (var i = 1; i < samples.length; i++) {
    final gap = samples[i].at - samples[i - 1].at;
    if (gap < idleMs) {
      activeMs += gap;
      measuredPages++;
      measuredWords += samples[i - 1].words ?? 0;
    }
  }

  return ReadingStats(
    buckets: buckets,
    totalPages: samples.length,
    totalWords: totalWords,
    measuredPages: measuredPages,
    measuredWords: measuredWords,
    activeReadingMinutes: activeMs / 60000,
  );
});

(int fromMs, List<ReadingBucket>) _bucketsFor(
  StatsRange range,
  DateTime now,
) {
  switch (range) {
    case StatsRange.day:
      // 24 hourly buckets ending at the current hour. Labels rotate
      // with the rolling window so the rightmost bar is "now".
      final start = DateTime(now.year, now.month, now.day, now.hour)
          .subtract(const Duration(hours: 23));
      final buckets = List<ReadingBucket>.generate(24, (i) {
        final h = start.add(Duration(hours: i)).hour;
        return ReadingBucket(label: '${h}h', pages: 0);
      });
      return (start.millisecondsSinceEpoch, buckets);
    case StatsRange.week:
      // Calendar week (Mon-Sun) so today's bar sits at its weekday
      // position — Tuesday is always the 2nd bar.
      final start = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
      const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final buckets = List<ReadingBucket>.generate(7, (i) {
        return ReadingBucket(label: dayNames[i], pages: 0);
      });
      return (start.millisecondsSinceEpoch, buckets);
    case StatsRange.month:
      // Calendar month so today's bar sits at the corresponding
      // day-of-month position (Apr 28 = 28th bar).
      final start = DateTime(now.year, now.month, 1);
      final daysInMonth =
          DateTime(now.year, now.month + 1, 0).day;
      final buckets = List<ReadingBucket>.generate(daysInMonth, (i) {
        // Sparse labels: every 5 days so the X-axis stays legible.
        final dayNum = i + 1;
        final label = (i % 5 == 0) ? dayNum.toString() : '';
        return ReadingBucket(label: label, pages: 0);
      });
      return (start.millisecondsSinceEpoch, buckets);
  }
}

int _bucketIndexFor(StatsRange range, DateTime t, DateTime now) {
  switch (range) {
    case StatsRange.day:
      final startOfRange =
          DateTime(now.year, now.month, now.day, now.hour)
              .subtract(const Duration(hours: 23));
      return t.difference(startOfRange).inHours;
    case StatsRange.week:
      // weekday: 1 = Mon ... 7 = Sun
      return t.weekday - 1;
    case StatsRange.month:
      // Same calendar month as `now`. Anything outside falls off
      // the chart (caught by the [0..length-1] bounds check upstream).
      if (t.year != now.year || t.month != now.month) return -1;
      return t.day - 1;
  }
}
