class Dictionary {
  Dictionary({
    this.id,
    required this.name,
    this.description,
    required this.createdAt,
    this.series,
  });

  final int? id;
  final String name;
  final String? description;
  final DateTime createdAt;

  /// When non-null, the dictionary's entries only apply to books whose
  /// `Book.series` matches this string. Null = global (applies to every
  /// book regardless of series).
  final String? series;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'description': description,
        'created_at': createdAt.millisecondsSinceEpoch,
        'series': series,
      };

  factory Dictionary.fromMap(Map<String, dynamic> m) => Dictionary(
        id: m['id'] as int?,
        name: m['name'] as String,
        description: m['description'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        series: m['series'] as String?,
      );
}
