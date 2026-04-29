class CharacterDescription {
  CharacterDescription({
    this.id,
    required this.characterId,
    required this.text,
    this.bookId,
    this.spoilerBookId,
    this.spoilerChapterIndex,
    required this.createdAt,
  });

  final int? id;
  final int characterId;
  final String text;

  /// Book the description was authored from.
  final int? bookId;

  /// Latest plot point this description references — used to hide the
  /// description from a reader who hasn't reached that point yet.
  /// Defaults to [bookId] / current chapter when not set, but can be
  /// overridden when authoring (e.g. "this is a non-spoiler bio").
  final int? spoilerBookId;
  final int? spoilerChapterIndex;

  final DateTime createdAt;

  bool get hasSpoilerAnchor =>
      spoilerBookId != null || spoilerChapterIndex != null;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'character_id': characterId,
        'text': text,
        'book_id': bookId,
        'spoiler_book_id': spoilerBookId,
        'spoiler_chapter_index': spoilerChapterIndex,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory CharacterDescription.fromMap(Map<String, dynamic> m) =>
      CharacterDescription(
        id: m['id'] as int?,
        characterId: m['character_id'] as int,
        text: m['text'] as String,
        bookId: m['book_id'] as int?,
        spoilerBookId: m['spoiler_book_id'] as int?,
        spoilerChapterIndex: m['spoiler_chapter_index'] as int?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}
