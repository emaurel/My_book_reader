class CharacterDescription {
  CharacterDescription({
    this.id,
    required this.characterId,
    required this.text,
    this.bookId,
    required this.createdAt,
  });

  final int? id;
  final int characterId;
  final String text;
  final int? bookId;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'character_id': characterId,
        'text': text,
        'book_id': bookId,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory CharacterDescription.fromMap(Map<String, dynamic> m) =>
      CharacterDescription(
        id: m['id'] as int?,
        characterId: m['character_id'] as int,
        text: m['text'] as String,
        bookId: m['book_id'] as int?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}
