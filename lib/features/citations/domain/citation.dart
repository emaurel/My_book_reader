class Citation {
  Citation({
    this.id,
    this.bookId,
    required this.text,
    required this.createdAt,
    this.chapterIndex,
    this.charStart,
    this.charEnd,
  });

  final int? id;

  /// Nullable so a citation survives the book being removed from the
  /// library. Resolved against [Book.id] when present.
  final int? bookId;

  final String text;
  final DateTime createdAt;

  /// Chapter index this citation lives in (EPUB only). Nullable for
  /// backward compatibility / formats without chapters.
  final int? chapterIndex;

  /// Absolute character offsets within the chapter's `<body>`. Used to
  /// re-highlight the citation when the chapter is rendered.
  final int? charStart;
  final int? charEnd;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'book_id': bookId,
        'text': text,
        'created_at': createdAt.millisecondsSinceEpoch,
        'chapter_index': chapterIndex,
        'char_start': charStart,
        'char_end': charEnd,
      };

  factory Citation.fromMap(Map<String, dynamic> m) => Citation(
        id: m['id'] as int?,
        bookId: m['book_id'] as int?,
        text: m['text'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        chapterIndex: m['chapter_index'] as int?,
        charStart: m['char_start'] as int?,
        charEnd: m['char_end'] as int?,
      );
}
