/// A user-created link from a passage in one book to another book in
/// the library. The selection's offsets are stored so we can later
/// render the link inline in the source book's reader (not yet wired
/// in the v0.3 first cut — links are surfaced via the Links screen).
class BookLink {
  BookLink({
    this.id,
    required this.sourceBookId,
    this.sourceChapterIndex,
    this.sourceCharStart,
    this.sourceCharEnd,
    required this.targetBookId,
    required this.label,
    required this.createdAt,
  });

  final int? id;
  final int sourceBookId;
  final int? sourceChapterIndex;
  final int? sourceCharStart;
  final int? sourceCharEnd;
  final int targetBookId;

  /// The selected text at the time the link was created. Used as the
  /// human-readable label in the Links list.
  final String label;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'source_book_id': sourceBookId,
        'source_chapter_index': sourceChapterIndex,
        'source_char_start': sourceCharStart,
        'source_char_end': sourceCharEnd,
        'target_book_id': targetBookId,
        'label': label,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory BookLink.fromMap(Map<String, dynamic> m) => BookLink(
        id: m['id'] as int?,
        sourceBookId: m['source_book_id'] as int,
        sourceChapterIndex: m['source_chapter_index'] as int?,
        sourceCharStart: m['source_char_start'] as int?,
        sourceCharEnd: m['source_char_end'] as int?,
        targetBookId: m['target_book_id'] as int,
        label: m['label'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}
