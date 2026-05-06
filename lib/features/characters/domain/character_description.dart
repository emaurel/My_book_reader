class CharacterDescription {
  CharacterDescription({
    this.id,
    required this.characterId,
    required this.text,
    this.bookId,
    this.spoilerBookId,
    this.spoilerChapterIndex,
    this.spoilerPageInChapter,
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

  /// Page within the spoiler chapter — lets the user gate "X dies on
  /// the last page of this chapter" so a reader on page 3 of the
  /// same chapter doesn't get spoiled.
  final int? spoilerPageInChapter;

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
        'spoiler_page_in_chapter': spoilerPageInChapter,
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
        spoilerPageInChapter: m['spoiler_page_in_chapter'] as int?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}
