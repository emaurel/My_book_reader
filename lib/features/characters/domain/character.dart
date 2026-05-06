enum CharacterStatus {
  alive,
  dead,
  missing,
  unknown;

  static CharacterStatus? fromName(String? name) {
    if (name == null || name.isEmpty) return null;
    for (final s in CharacterStatus.values) {
      if (s.name == name) return s;
    }
    return null;
  }
}

class Character {
  Character({
    this.id,
    required this.name,
    this.series,
    required this.createdAt,
    DateTime? updatedAt,
    CharacterStatus? status,
    this.statusCustomId,
    this.statusSpoilerBookId,
    this.statusSpoilerChapterIndex,
    this.statusSpoilerPageInChapter,
    this.firstSeenBookId,
    this.firstSeenChapterIndex,
    this.firstSeenPageInChapter,
  })  : status = status ?? CharacterStatus.alive,
        updatedAt = updatedAt ?? createdAt;

  final int? id;
  final String name;

  /// Null = global character (visible across every book). Otherwise the
  /// character only applies to books whose `Book.series` matches.
  final String? series;
  final DateTime createdAt;

  /// Bumped whenever a description or alias is added / edited / removed
  /// for the character. Used to sort lists by last-touched first.
  final DateTime updatedAt;

  /// Default narrative status — the value that applies when the reader
  /// is before any history entry, or when the timeline is empty.
  /// Defaults to [CharacterStatus.alive] when not explicitly set.
  final CharacterStatus status;

  /// When non-null, refers to a row in `custom_statuses` and overrides
  /// [status] for display. The enum value is then a placeholder used
  /// only to satisfy the legacy NOT NULL constraint on the column.
  final int? statusCustomId;

  /// Legacy single-status spoiler anchor. Migrated into the
  /// `character_status_history` table at DB v20; the columns are kept
  /// for backwards compatibility but new writes should use the history
  /// table via `addStatusEntry()`.
  final int? statusSpoilerBookId;
  final int? statusSpoilerChapterIndex;
  final int? statusSpoilerPageInChapter;

  /// First narrative appearance of the character. When the reader is
  /// at a position earlier than this, the character is rendered as a
  /// "Hidden character" placeholder in lists so the user isn't spoiled
  /// about who exists later in the series.
  final int? firstSeenBookId;
  final int? firstSeenChapterIndex;
  final int? firstSeenPageInChapter;

  bool get hasFirstSeenAnchor =>
      firstSeenBookId != null || firstSeenChapterIndex != null;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'series': series,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'status': status.name,
        'status_custom_id': statusCustomId,
        'status_spoiler_book_id': statusSpoilerBookId,
        'status_spoiler_chapter_index': statusSpoilerChapterIndex,
        'status_spoiler_page_in_chapter': statusSpoilerPageInChapter,
        'first_seen_book_id': firstSeenBookId,
        'first_seen_chapter_index': firstSeenChapterIndex,
        'first_seen_page_in_chapter': firstSeenPageInChapter,
      };

  factory Character.fromMap(Map<String, dynamic> m) => Character(
        id: m['id'] as int?,
        name: m['name'] as String,
        series: m['series'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        updatedAt: m['updated_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int)
            : null,
        status: CharacterStatus.fromName(m['status'] as String?),
        statusCustomId: m['status_custom_id'] as int?,
        statusSpoilerBookId: m['status_spoiler_book_id'] as int?,
        statusSpoilerChapterIndex:
            m['status_spoiler_chapter_index'] as int?,
        statusSpoilerPageInChapter:
            m['status_spoiler_page_in_chapter'] as int?,
        firstSeenBookId: m['first_seen_book_id'] as int?,
        firstSeenChapterIndex: m['first_seen_chapter_index'] as int?,
        firstSeenPageInChapter: m['first_seen_page_in_chapter'] as int?,
      );
}
