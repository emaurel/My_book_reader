class Character {
  Character({
    this.id,
    required this.name,
    this.series,
    required this.createdAt,
  });

  final int? id;
  final String name;

  /// Null = global character (visible across every book). Otherwise the
  /// character only applies to books whose `Book.series` matches.
  final String? series;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'series': series,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Character.fromMap(Map<String, dynamic> m) => Character(
        id: m['id'] as int?,
        name: m['name'] as String,
        series: m['series'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}
