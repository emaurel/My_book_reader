class Affiliation {
  Affiliation({
    this.id,
    required this.name,
    this.series,
    this.parentId,
    required this.createdAt,
  });

  final int? id;
  final String name;

  /// Null = global affiliation (visible across every book). Otherwise
  /// scoped to a single series, just like characters and dictionaries.
  final String? series;

  /// Optional parent affiliation — lets the user model nested
  /// factions like "OPA → Belt". Null = top-level.
  final int? parentId;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'series': series,
        'parent_id': parentId,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Affiliation.fromMap(Map<String, dynamic> m) => Affiliation(
        id: m['id'] as int?,
        name: m['name'] as String,
        series: m['series'] as String?,
        parentId: m['parent_id'] as int?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}
