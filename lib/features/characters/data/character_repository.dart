import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../domain/affiliation.dart';
import '../domain/character.dart';
import '../domain/character_description.dart';
import '../domain/character_relationship.dart';
import '../domain/character_status_entry.dart';
import '../domain/custom_status.dart';

class CharacterRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  /// Bump `characters.updated_at` so the character moves to the top of
  /// "by last modified" sorts. Called after every description / alias
  /// mutation. Safe to call with a non-existent id (no-op).
  Future<void> _touchCharacter(int characterId) async {
    final db = await _db;
    await db.update(
      'characters',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [characterId],
    );
  }

  static const _orderClause =
      'COALESCE(updated_at, created_at) DESC, name COLLATE NOCASE ASC';

  // ---- Characters ----

  Future<List<Character>> listAll() async {
    final db = await _db;
    final rows = await db.query('characters', orderBy: _orderClause);
    return rows.map(Character.fromMap).toList();
  }

  /// Characters that apply to a book in [series]: global characters
  /// (`series IS NULL`) plus any whose series matches. Ordered by
  /// last-modified first so recently-touched names surface in the
  /// add-description picker.
  Future<List<Character>> listForSeries(String? series) async {
    final db = await _db;
    final List<Map<String, Object?>> rows;
    if (series == null) {
      rows = await db.query(
        'characters',
        where: 'series IS NULL',
        orderBy: _orderClause,
      );
    } else {
      rows = await db.query(
        'characters',
        where: 'series IS NULL OR series = ?',
        whereArgs: [series],
        orderBy: _orderClause,
      );
    }
    return rows.map(Character.fromMap).toList();
  }

  Future<int> create({required String name, String? series}) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.insert('characters', {
      'name': name,
      'series': series,
      'created_at': now,
      'updated_at': now,
      'status': 'alive',
    });
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('characters', where: 'id = ?', whereArgs: [id]);
  }

  Future<Character?> findByName(String name, {String? series}) async {
    final db = await _db;
    final List<Map<String, Object?>> rows;
    if (series == null) {
      rows = await db.query(
        'characters',
        where: 'name = ? COLLATE NOCASE AND series IS NULL',
        whereArgs: [name],
        limit: 1,
      );
    } else {
      rows = await db.query(
        'characters',
        where: 'name = ? COLLATE NOCASE AND (series IS NULL OR series = ?)',
        whereArgs: [name, series],
        limit: 1,
      );
    }
    if (rows.isEmpty) return null;
    return Character.fromMap(rows.first);
  }

  // ---- Descriptions ----

  Future<int> addDescription({
    required int characterId,
    required String text,
    int? bookId,
    int? spoilerBookId,
    int? spoilerChapterIndex,
    int? spoilerPageInChapter,
  }) async {
    final db = await _db;
    final id = await db.insert('character_descriptions', {
      'character_id': characterId,
      'text': text,
      'book_id': bookId,
      'spoiler_book_id': spoilerBookId,
      'spoiler_chapter_index': spoilerChapterIndex,
      'spoiler_page_in_chapter': spoilerPageInChapter,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    await _touchCharacter(characterId);
    return id;
  }

  /// Updates the spoiler-anchor pair on an existing description so the
  /// user can re-tag a note ("actually this isn't a spoiler" / "this
  /// references chapter X").
  Future<void> updateDescriptionSpoiler({
    required int id,
    int? spoilerBookId,
    int? spoilerChapterIndex,
  }) async {
    final db = await _db;
    await db.update(
      'character_descriptions',
      {
        'spoiler_book_id': spoilerBookId,
        'spoiler_chapter_index': spoilerChapterIndex,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateDescription({
    required int id,
    required String text,
  }) async {
    final db = await _db;
    await db.update(
      'character_descriptions',
      {'text': text},
      where: 'id = ?',
      whereArgs: [id],
    );
    final rows = await db.query(
      'character_descriptions',
      columns: ['character_id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      await _touchCharacter(rows.first['character_id'] as int);
    }
  }

  Future<void> deleteDescription(int id) async {
    final db = await _db;
    final rows = await db.query(
      'character_descriptions',
      columns: ['character_id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    await db.delete('character_descriptions', where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      await _touchCharacter(rows.first['character_id'] as int);
    }
  }

  Future<List<CharacterDescription>> descriptionsForCharacter(
    int characterId,
  ) async {
    final db = await _db;
    final rows = await db.query(
      'character_descriptions',
      where: 'character_id = ?',
      whereArgs: [characterId],
      orderBy: 'created_at ASC',
    );
    return rows.map(CharacterDescription.fromMap).toList();
  }

  // ---- Aliases ----

  Future<List<String>> aliasesForCharacter(int characterId) async {
    final db = await _db;
    final rows = await db.query(
      'character_aliases',
      where: 'character_id = ?',
      whereArgs: [characterId],
      orderBy: 'alias COLLATE NOCASE ASC',
    );
    return rows.map((r) => r['alias'] as String).toList();
  }

  Future<int> addAlias({required int characterId, required String alias}) async {
    final db = await _db;
    final id = await db.insert(
      'character_aliases',
      {'character_id': characterId, 'alias': alias},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await _touchCharacter(characterId);
    return id;
  }

  Future<void> deleteAlias({required int characterId, required String alias}) async {
    final db = await _db;
    await db.delete(
      'character_aliases',
      where: 'character_id = ? AND alias = ? COLLATE NOCASE',
      whereArgs: [characterId, alias],
    );
    await _touchCharacter(characterId);
  }

  /// Map of character_id → list of aliases for the given series scope.
  /// Used by the EPUB viewer to compose the regex with each character's
  /// canonical name plus all their aliases.
  Future<Map<int, List<String>>> aliasesByCharacter(String? series) async {
    final db = await _db;
    final List<Map<String, Object?>> rows;
    if (series == null) {
      rows = await db.rawQuery('''
        SELECT a.character_id, a.alias FROM character_aliases a
        JOIN characters c ON c.id = a.character_id
        WHERE c.series IS NULL
      ''');
    } else {
      rows = await db.rawQuery('''
        SELECT a.character_id, a.alias FROM character_aliases a
        JOIN characters c ON c.id = a.character_id
        WHERE c.series IS NULL OR c.series = ?
      ''', [series]);
    }
    final out = <int, List<String>>{};
    for (final r in rows) {
      final id = r['character_id'] as int;
      final alias = r['alias'] as String;
      (out[id] ??= []).add(alias);
    }
    return out;
  }

  /// Find a character by name OR alias. Used when the user taps an
  /// underlined token in the reader so we can identify which character
  /// it belongs to.
  // ---- Affiliations ----

  /// Every affiliation across every series — used by the delete
  /// picker so the user can pick any affiliation regardless of which
  /// series it belongs to.
  Future<List<Affiliation>> listAllAffiliations() async {
    final db = await _db;
    final rows = await db.query(
      'affiliations',
      orderBy: 'series COLLATE NOCASE ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(Affiliation.fromMap).toList();
  }

  Future<List<Affiliation>> listAffiliationsForSeries(String? series) async {
    final db = await _db;
    final List<Map<String, Object?>> rows;
    if (series == null) {
      rows = await db.query(
        'affiliations',
        where: 'series IS NULL',
        orderBy: 'name COLLATE NOCASE ASC',
      );
    } else {
      rows = await db.query(
        'affiliations',
        where: 'series IS NULL OR series = ?',
        whereArgs: [series],
        orderBy: 'name COLLATE NOCASE ASC',
      );
    }
    return rows.map(Affiliation.fromMap).toList();
  }

  Future<int> createAffiliation({
    required String name,
    String? series,
    int? parentId,
  }) async {
    final db = await _db;
    return db.insert(
      'affiliations',
      {
        'name': name,
        'series': series,
        'parent_id': parentId,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> deleteAffiliation(int id) async {
    final db = await _db;
    await db.delete('affiliations', where: 'id = ?', whereArgs: [id]);
  }

  /// Reparent an affiliation. Used by the Characters screen's
  /// affiliation-tree editor.
  Future<void> setAffiliationParent({
    required int affiliationId,
    int? parentId,
  }) async {
    final db = await _db;
    await db.update(
      'affiliations',
      {'parent_id': parentId},
      where: 'id = ?',
      whereArgs: [affiliationId],
    );
  }

  Future<List<Affiliation>> affiliationsForCharacter(int characterId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT a.* FROM affiliations a
      JOIN character_affiliations ca ON ca.affiliation_id = a.id
      WHERE ca.character_id = ?
      ORDER BY a.name COLLATE NOCASE ASC
    ''', [characterId]);
    return rows.map(Affiliation.fromMap).toList();
  }

  /// All character_id → list-of-affiliations within a series scope.
  /// Used to build the Characters management screen's grouping.
  Future<Map<int, List<Affiliation>>> affiliationsByCharacter(
    String? series,
  ) async {
    final db = await _db;
    final List<Map<String, Object?>> rows;
    if (series == null) {
      rows = await db.rawQuery('''
        SELECT ca.character_id, a.*
        FROM character_affiliations ca
        JOIN affiliations a ON a.id = ca.affiliation_id
        JOIN characters c ON c.id = ca.character_id
        WHERE c.series IS NULL
      ''');
    } else {
      rows = await db.rawQuery('''
        SELECT ca.character_id, a.*
        FROM character_affiliations ca
        JOIN affiliations a ON a.id = ca.affiliation_id
        JOIN characters c ON c.id = ca.character_id
        WHERE c.series IS NULL OR c.series = ?
      ''', [series]);
    }
    final out = <int, List<Affiliation>>{};
    for (final r in rows) {
      final cid = r['character_id'] as int;
      (out[cid] ??= []).add(Affiliation.fromMap(r));
    }
    return out;
  }

  Future<void> linkAffiliation({
    required int characterId,
    required int affiliationId,
  }) async {
    final db = await _db;
    await db.insert(
      'character_affiliations',
      {'character_id': characterId, 'affiliation_id': affiliationId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await _touchCharacter(characterId);
  }

  Future<void> unlinkAffiliation({
    required int characterId,
    required int affiliationId,
  }) async {
    final db = await _db;
    await db.delete(
      'character_affiliations',
      where: 'character_id = ? AND affiliation_id = ?',
      whereArgs: [characterId, affiliationId],
    );
    await _touchCharacter(characterId);
  }

  Future<Character?> findByNameOrAlias(
    String name, {
    String? series,
  }) async {
    final db = await _db;
    final List<Map<String, Object?>> rows;
    if (series == null) {
      rows = await db.rawQuery('''
        SELECT DISTINCT c.* FROM characters c
        LEFT JOIN character_aliases a ON a.character_id = c.id
        WHERE c.series IS NULL
          AND (c.name = ? COLLATE NOCASE OR a.alias = ? COLLATE NOCASE)
        LIMIT 1
      ''', [name, name]);
    } else {
      rows = await db.rawQuery('''
        SELECT DISTINCT c.* FROM characters c
        LEFT JOIN character_aliases a ON a.character_id = c.id
        WHERE (c.series IS NULL OR c.series = ?)
          AND (c.name = ? COLLATE NOCASE OR a.alias = ? COLLATE NOCASE)
        LIMIT 1
      ''', [series, name, name]);
    }
    if (rows.isEmpty) return null;
    return Character.fromMap(rows.first);
  }

  // ---- Status ----

  /// Update the narrative status of a character. Pass null to clear.
  /// The spoiler-anchor pair lets the in-reader popup hide spoiler
  /// statuses (e.g. "dead") for readers ahead of that point.
  Future<void> setStatus({
    required int characterId,
    required CharacterStatus status,
    int? spoilerBookId,
    int? spoilerChapterIndex,
    int? spoilerPageInChapter,
  }) async {
    final db = await _db;
    await db.update(
      'characters',
      {
        'status': status.name,
        'status_spoiler_book_id': spoilerBookId,
        'status_spoiler_chapter_index': spoilerChapterIndex,
        'status_spoiler_page_in_chapter': spoilerPageInChapter,
      },
      where: 'id = ?',
      whereArgs: [characterId],
    );
    await _touchCharacter(characterId);
  }

  /// Per-character status timeline. Ordered by (book, chapter, page)
  /// so the latest entry the reader has reached is found by linear
  /// scan from the end. Anchors that share a book ordered by chapter
  /// then page; entries with a NULL anchor land at the start.
  Future<List<CharacterStatusEntry>> listStatusEntries(
    int characterId,
  ) async {
    final db = await _db;
    final rows = await db.query(
      'character_status_history',
      where: 'character_id = ?',
      whereArgs: [characterId],
      orderBy: 'created_at ASC',
    );
    return rows.map(CharacterStatusEntry.fromMap).toList();
  }

  Future<int> addStatusEntry({
    required int characterId,
    required CharacterStatus status,
    int? customStatusId,
    int? bookId,
    int? chapterIndex,
    int? pageInChapter,
    String? note,
  }) async {
    final db = await _db;
    final id = await db.insert('character_status_history', {
      'character_id': characterId,
      'status': status.name,
      'custom_status_id': customStatusId,
      'book_id': bookId,
      'chapter_index': chapterIndex,
      'page_in_chapter': pageInChapter,
      'note': note,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    await _touchCharacter(characterId);
    return id;
  }

  Future<void> deleteStatusEntry(int id) async {
    final db = await _db;
    final rows = await db.query(
      'character_status_history',
      columns: ['character_id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    await db.delete(
      'character_status_history',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isNotEmpty) {
      await _touchCharacter(rows.first['character_id'] as int);
    }
  }

  /// Replaces the character's default narrative status — the value
  /// shown in the synthetic "first row" of the timeline before any
  /// recorded change applies. Pass [customStatusId] to point at a
  /// custom row (the [status] enum then acts as a placeholder for
  /// the NOT NULL column constraint).
  Future<void> setDefaultStatus({
    required int characterId,
    required CharacterStatus status,
    int? customStatusId,
  }) async {
    final db = await _db;
    await db.update(
      'characters',
      {
        'status': status.name,
        'status_custom_id': customStatusId,
      },
      where: 'id = ?',
      whereArgs: [characterId],
    );
    await _touchCharacter(characterId);
  }

  // ---- Custom statuses ----

  Future<List<CustomStatus>> listCustomStatuses() async {
    final db = await _db;
    final rows = await db.query(
      'custom_statuses',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(CustomStatus.fromMap).toList();
  }

  Future<int> createCustomStatus({
    required String name,
    required int colorArgb,
  }) async {
    final db = await _db;
    return db.insert('custom_statuses', {
      'name': name,
      'color': colorArgb,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updateCustomStatus({
    required int id,
    required String name,
    required int colorArgb,
  }) async {
    final db = await _db;
    await db.update(
      'custom_statuses',
      {'name': name, 'color': colorArgb},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteCustomStatus(int id) async {
    final db = await _db;
    await db.delete('custom_statuses', where: 'id = ?', whereArgs: [id]);
  }

  /// Records the first appearance of a character. Lists outside the
  /// reader (or readers ahead of the anchor) see the character as
  /// "Hidden character" until they reach this position.
  Future<void> setFirstSeen({
    required int characterId,
    int? bookId,
    int? chapterIndex,
    int? pageInChapter,
  }) async {
    final db = await _db;
    await db.update(
      'characters',
      {
        'first_seen_book_id': bookId,
        'first_seen_chapter_index': chapterIndex,
        'first_seen_page_in_chapter': pageInChapter,
      },
      where: 'id = ?',
      whereArgs: [characterId],
    );
    await _touchCharacter(characterId);
  }

  // ---- Relationships ----

  Future<int> addRelationship({
    required int fromCharacterId,
    required int toCharacterId,
    required RelationshipKind kind,
    String? note,
    int? spoilerBookId,
    int? spoilerChapterIndex,
    int? spoilerPageInChapter,
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert(
      'character_relationships',
      {
        'from_character_id': fromCharacterId,
        'to_character_id': toCharacterId,
        'kind': kind.name,
        'note': note,
        'spoiler_book_id': spoilerBookId,
        'spoiler_chapter_index': spoilerChapterIndex,
        'spoiler_page_in_chapter': spoilerPageInChapter,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    // Auto-add the inverse so the graph is consistent without the
    // user having to enter the same relation from the other side.
    final inverse = kind.inverse;
    final alreadySymmetric = inverse == kind;
    if (!alreadySymmetric || fromCharacterId != toCharacterId) {
      await db.insert(
        'character_relationships',
        {
          'from_character_id': toCharacterId,
          'to_character_id': fromCharacterId,
          'kind': inverse.name,
          'note': note,
          'spoiler_book_id': spoilerBookId,
          'spoiler_chapter_index': spoilerChapterIndex,
          'spoiler_page_in_chapter': spoilerPageInChapter,
          'created_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await _touchCharacter(fromCharacterId);
    await _touchCharacter(toCharacterId);
    return id;
  }

  Future<void> deleteRelationship(int id) async {
    final db = await _db;
    // Look up the row first so we can also remove its inverse pair.
    final rows = await db.query(
      'character_relationships',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final r = CharacterRelationship.fromMap(rows.first);
    await db.delete(
      'character_relationships',
      where: '(from_character_id = ? AND to_character_id = ? AND kind = ?) '
          'OR (from_character_id = ? AND to_character_id = ? AND kind = ?)',
      whereArgs: [
        r.fromCharacterId,
        r.toCharacterId,
        r.kind.name,
        r.toCharacterId,
        r.fromCharacterId,
        r.kind.inverse.name,
      ],
    );
    await _touchCharacter(r.fromCharacterId);
    await _touchCharacter(r.toCharacterId);
  }

  /// Outgoing relationships from a character. Used by the character
  /// sheet's relationships section.
  Future<List<CharacterRelationship>> relationshipsFrom(
    int characterId,
  ) async {
    final db = await _db;
    final rows = await db.query(
      'character_relationships',
      where: 'from_character_id = ?',
      whereArgs: [characterId],
      orderBy: 'created_at ASC',
    );
    return rows.map(CharacterRelationship.fromMap).toList();
  }

  /// Every relationship in the database — used by the global graph
  /// view to render the entire web of character connections.
  Future<List<CharacterRelationship>> allRelationships() async {
    final db = await _db;
    final rows = await db.query(
      'character_relationships',
      orderBy: 'created_at ASC',
    );
    return rows.map(CharacterRelationship.fromMap).toList();
  }
}
