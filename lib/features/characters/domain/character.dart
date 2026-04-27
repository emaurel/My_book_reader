class Character {
  Character({
    this.id,
    required this.name,
    this.series,
    required this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  final int? id;
  final String name;

  /// Null = global character (visible across every book). Otherwise the
  /// character only applies to books whose `Book.series` matches.
  final String? series;
  final DateTime createdAt;

  /// Bumped whenever a description or alias is added / edited / removed
  /// for the character. Used to sort lists by last-touched first.
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'series': series,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory Character.fromMap(Map<String, dynamic> m) => Character(
        id: m['id'] as int?,
        name: m['name'] as String,
        series: m['series'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        updatedAt: m['updated_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int)
            : null,
      );
}
