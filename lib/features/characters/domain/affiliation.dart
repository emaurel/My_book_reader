class Affiliation {
  Affiliation({
    this.id,
    required this.name,
    this.series,
    required this.createdAt,
  });

  final int? id;
  final String name;

  /// Null = global affiliation (visible across every book). Otherwise
  /// scoped to a single series, just like characters and dictionaries.
  final String? series;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'series': series,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Affiliation.fromMap(Map<String, dynamic> m) => Affiliation(
        id: m['id'] as int?,
        name: m['name'] as String,
        series: m['series'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}
