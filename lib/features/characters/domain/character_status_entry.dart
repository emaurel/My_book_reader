import 'character.dart';

/// One entry on a character's status timeline. Reads as
/// "from (book, chapter, page) onward, this character is [status]".
/// The status that applies at a given reader position is the latest
/// entry whose anchor sits at-or-before the reader; if none does, the
/// character's default `status` field on the row applies.
class CharacterStatusEntry {
  CharacterStatusEntry({
    this.id,
    required this.characterId,
    required this.status,
    this.customStatusId,
    this.bookId,
    this.chapterIndex,
    this.pageInChapter,
    this.note,
    required this.createdAt,
  });

  final int? id;
  final int characterId;
  final CharacterStatus status;

  /// When non-null, refers to a row in `custom_statuses` and overrides
  /// [status] for display. The enum value is then a placeholder used
  /// only to satisfy the legacy NOT NULL constraint on the column.
  final int? customStatusId;

  /// The (book, chapter, page) triple this entry starts from. A null
  /// triple means "from the very beginning" — useful as the implicit
  /// fallback that's almost never written explicitly.
  final int? bookId;
  final int? chapterIndex;
  final int? pageInChapter;

  /// Optional free-form annotation ("captured by the empire", "revived
  /// in the prologue of book 4") to remind the user *why* the status
  /// changed. Not used in any logic.
  final String? note;

  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'character_id': characterId,
        'status': status.name,
        'custom_status_id': customStatusId,
        'book_id': bookId,
        'chapter_index': chapterIndex,
        'page_in_chapter': pageInChapter,
        'note': note,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory CharacterStatusEntry.fromMap(Map<String, dynamic> m) =>
      CharacterStatusEntry(
        id: m['id'] as int?,
        characterId: m['character_id'] as int,
        status: CharacterStatus.fromName(m['status'] as String?) ??
            CharacterStatus.alive,
        customStatusId: m['custom_status_id'] as int?,
        bookId: m['book_id'] as int?,
        chapterIndex: m['chapter_index'] as int?,
        pageInChapter: m['page_in_chapter'] as int?,
        note: m['note'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}
