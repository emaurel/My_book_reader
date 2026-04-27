/// A free-form annotation the user attaches to a passage in a book.
/// Distinct from citations (which save the quote) and dictionary
/// entries (which gloss a single word).
class Note {
  Note({
    this.id,
    this.bookId,
    this.chapterIndex,
    this.charStart,
    this.charEnd,
    required this.selectedText,
    required this.noteText,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final int? bookId;
  final int? chapterIndex;
  final int? charStart;
  final int? charEnd;

  /// The passage that was selected when the note was created — used
  /// as the row's title in the notes list when the book is missing.
  final String selectedText;

  final String noteText;
  final DateTime createdAt;
  final DateTime updatedAt;

  Note copyWith({String? noteText, DateTime? updatedAt}) => Note(
        id: id,
        bookId: bookId,
        chapterIndex: chapterIndex,
        charStart: charStart,
        charEnd: charEnd,
        selectedText: selectedText,
        noteText: noteText ?? this.noteText,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory Note.fromMap(Map<String, dynamic> m) => Note(
        id: m['id'] as int?,
        bookId: m['book_id'] as int?,
        chapterIndex: m['chapter_index'] as int?,
        charStart: m['char_start'] as int?,
        charEnd: m['char_end'] as int?,
        selectedText: m['selected_text'] as String,
        noteText: m['note_text'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int),
      );
}
