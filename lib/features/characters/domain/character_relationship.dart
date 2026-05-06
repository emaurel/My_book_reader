/// Typed edges between characters. Stored as a directed pair
/// (`from`, `to`) plus a [kind]; readers display reciprocal edges
/// either by inserting the inverse pair on save or by symmetric
/// queries on the graph view.
enum RelationshipKind {
  parent,
  child,
  sibling,
  spouse,
  partner,
  friend,
  rival,
  enemy,
  mentor,
  student,
  ally,
  other;

  static RelationshipKind fromName(String name) {
    for (final k in RelationshipKind.values) {
      if (k.name == name) return k;
    }
    return RelationshipKind.other;
  }

  /// Inverse used when the user adds a "parent" relation — we also
  /// store the corresponding "child" automatically so the graph
  /// reflects both sides without the user double-entering.
  RelationshipKind get inverse {
    switch (this) {
      case RelationshipKind.parent:
        return RelationshipKind.child;
      case RelationshipKind.child:
        return RelationshipKind.parent;
      case RelationshipKind.mentor:
        return RelationshipKind.student;
      case RelationshipKind.student:
        return RelationshipKind.mentor;
      // The rest are symmetric — same kind on both ends.
      case RelationshipKind.sibling:
      case RelationshipKind.spouse:
      case RelationshipKind.partner:
      case RelationshipKind.friend:
      case RelationshipKind.rival:
      case RelationshipKind.enemy:
      case RelationshipKind.ally:
      case RelationshipKind.other:
        return this;
    }
  }
}

class CharacterRelationship {
  CharacterRelationship({
    this.id,
    required this.fromCharacterId,
    required this.toCharacterId,
    required this.kind,
    this.note,
    this.spoilerBookId,
    this.spoilerChapterIndex,
    required this.createdAt,
  });

  final int? id;
  final int fromCharacterId;
  final int toCharacterId;
  final RelationshipKind kind;
  final String? note;
  final int? spoilerBookId;
  final int? spoilerChapterIndex;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'from_character_id': fromCharacterId,
        'to_character_id': toCharacterId,
        'kind': kind.name,
        'note': note,
        'spoiler_book_id': spoilerBookId,
        'spoiler_chapter_index': spoilerChapterIndex,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory CharacterRelationship.fromMap(Map<String, dynamic> m) =>
      CharacterRelationship(
        id: m['id'] as int?,
        fromCharacterId: m['from_character_id'] as int,
        toCharacterId: m['to_character_id'] as int,
        kind: RelationshipKind.fromName(m['kind'] as String),
        note: m['note'] as String?,
        spoilerBookId: m['spoiler_book_id'] as int?,
        spoilerChapterIndex: m['spoiler_chapter_index'] as int?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}
