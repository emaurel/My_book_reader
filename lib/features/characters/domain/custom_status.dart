/// User-defined status alongside the four built-in [CharacterStatus]
/// values. Unlike the enum these can be renamed and recolored, and
/// the user can add as many as they want — useful when a single
/// "alive/dead/missing" axis isn't enough (e.g. "Imprisoned",
/// "Possessed", "Cursed"). The color is stored as packed ARGB to
/// match Flutter's `Color.value`.
class CustomStatus {
  CustomStatus({
    this.id,
    required this.name,
    required this.colorArgb,
    required this.createdAt,
  });

  final int? id;
  final String name;
  final int colorArgb;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'color': colorArgb,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory CustomStatus.fromMap(Map<String, dynamic> m) => CustomStatus(
        id: m['id'] as int?,
        name: m['name'] as String,
        colorArgb: m['color'] as int,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}
