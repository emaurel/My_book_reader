class DictionaryEntry {
  DictionaryEntry({
    this.id,
    required this.dictionaryId,
    required this.word,
    required this.definition,
    required this.createdAt,
  });

  final int? id;
  final int dictionaryId;
  final String word;
  final String definition;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'dictionary_id': dictionaryId,
        'word': word,
        'definition': definition,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory DictionaryEntry.fromMap(Map<String, dynamic> m) => DictionaryEntry(
        id: m['id'] as int?,
        dictionaryId: m['dictionary_id'] as int,
        word: m['word'] as String,
        definition: m['definition'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}
