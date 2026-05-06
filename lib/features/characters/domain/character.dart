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
    this.status,
    this.statusSpoilerBookId,
    this.statusSpoilerChapterIndex,
  }) : updatedAt = updatedAt ?? createdAt;

  final int? id;
  final String name;

  /// Null = global character (visible across every book). Otherwise the
  /// character only applies to books whose `Book.series` matches.
  final String? series;
  final DateTime createdAt;

  /// Bumped whenever a description or alias is added / edited / removed
  /// for the character. Used to sort lists by last-touched first.
  final DateTime updatedAt;

  /// Current narrative status (alive / dead / missing / unknown).
  /// Null when not set.
  final CharacterStatus? status;

  /// Spoiler-anchor for [status] — when the user reads from inside a
  /// book that's earlier than this anchor, the in-reader popup shows
  /// "unknown" instead of the actual status.
  final int? statusSpoilerBookId;
  final int? statusSpoilerChapterIndex;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'series': series,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'status': status?.name,
        'status_spoiler_book_id': statusSpoilerBookId,
        'status_spoiler_chapter_index': statusSpoilerChapterIndex,
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
        statusSpoilerBookId: m['status_spoiler_book_id'] as int?,
        statusSpoilerChapterIndex:
            m['status_spoiler_chapter_index'] as int?,
      );
}
