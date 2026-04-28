/// One bar in the reading-stats bar chart. [label] is the X-axis text
/// (e.g. "14h", "Mon", "Apr 12"); [pages] is the bar height.
class ReadingBucket {
  const ReadingBucket({required this.label, required this.pages});
  final String label;
  final int pages;
}

class ReadingStats {
  const ReadingStats({
    required this.buckets,
    required this.totalPages,
    required this.totalWords,
    required this.measuredPages,
    required this.measuredWords,
    required this.activeReadingMinutes,
  });

  final List<ReadingBucket> buckets;

  /// Total pages and words observed in the range — every logged turn
  /// counts. Used for the headline "Pages" / "Words" cards.
  final int totalPages;
  final int totalWords;

  /// Pages and words for which we have a complete timing window
  /// (an inter-turn gap under the idle threshold). N logged turns
  /// produce at most N-1 measured pages — the time spent on the
  /// first and last pages of a session is unknowable.
  final int measuredPages;
  final int measuredWords;

  /// Sum of inter-page gaps under the 5-minute idle threshold.
  final double activeReadingMinutes;

  double get pagesPerHour {
    if (activeReadingMinutes <= 0 || measuredPages <= 0) return 0;
    return measuredPages / (activeReadingMinutes / 60);
  }

  double get wordsPerHour {
    if (activeReadingMinutes <= 0 || measuredWords <= 0) return 0;
    return measuredWords / (activeReadingMinutes / 60);
  }
}

enum StatsRange { day, week, month }

class AllTimeStats {
  const AllTimeStats({
    required this.totalPages,
    required this.totalWords,
    required this.booksFinished,
    required this.firstActivityAt,
  });

  final int totalPages;
  final int totalWords;
  final int booksFinished;

  /// Timestamp of the earliest logged page turn — null when the user
  /// has never read anything. Used to bound how far back the month
  /// pager goes in the All-time tab.
  final DateTime? firstActivityAt;
}

/// Identifies one calendar-month chart in the all-time view.
class StatsMonth {
  const StatsMonth(this.year, this.month);
  final int year;
  final int month;

  @override
  bool operator ==(Object other) =>
      other is StatsMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}
