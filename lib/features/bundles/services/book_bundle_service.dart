import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/database/database_helper.dart';
import '../../book_links/data/book_link_repository.dart';
import '../../characters/data/character_repository.dart';
import '../../characters/domain/affiliation.dart';
import '../../characters/domain/character.dart';
import '../../characters/domain/character_relationship.dart';
import '../../citations/data/citation_repository.dart';
import '../../dictionary/data/dictionary_repository.dart';
import '../../dictionary/domain/dictionary.dart';
import '../../library/data/book_repository.dart';
import '../../library/domain/book.dart';
import '../../library/services/book_metadata_extractor.dart';
import '../../notes/data/note_repository.dart';

class BookBundleResult {
  BookBundleResult({required this.savedPath, required this.bytes});
  final String savedPath;
  final int bytes;
}

class ImportSummary {
  ImportSummary({
    required this.booksAdded,
    required this.booksMerged,
    required this.citationsAdded,
    required this.notesAdded,
    required this.charactersAdded,
    required this.descriptionsAdded,
    required this.dictionaryEntriesAdded,
    required this.linksAdded,
  });

  final int booksAdded;
  final int booksMerged;
  final int citationsAdded;
  final int notesAdded;
  final int charactersAdded;
  final int descriptionsAdded;
  final int dictionaryEntriesAdded;
  final int linksAdded;
}

class BundlePreview {
  BundlePreview({
    required this.rootTitle,
    required this.bookCount,
    required this.citationCount,
    required this.noteCount,
    required this.characterCount,
    required this.dictionaryCount,
    required this.linkCount,
    required this.includesProgress,
    required this.bookTitles,
    required this.createdAt,
  });

  final String rootTitle;
  final int bookCount;
  final int citationCount;
  final int noteCount;
  final int characterCount;
  final int dictionaryCount;
  final int linkCount;
  final bool includesProgress;
  final List<String> bookTitles;
  final String? createdAt;
}

class BookBundleService {
  BookBundleService({
    BookRepository? bookRepo,
    BookLinkRepository? linkRepo,
    CitationRepository? citationRepo,
    NoteRepository? noteRepo,
    CharacterRepository? characterRepo,
    DictionaryRepository? dictionaryRepo,
    BookMetadataExtractor? extractor,
  })  : _books = bookRepo ?? BookRepository(),
        _links = linkRepo ?? BookLinkRepository(),
        _citations = citationRepo ?? CitationRepository(),
        _notes = noteRepo ?? NoteRepository(),
        _characters = characterRepo ?? CharacterRepository(),
        _dictionaries = dictionaryRepo ?? DictionaryRepository(),
        _extractor = extractor ?? BookMetadataExtractor();

  final BookRepository _books;
  final BookLinkRepository _links;
  final CitationRepository _citations;
  final NoteRepository _notes;
  final CharacterRepository _characters;
  final DictionaryRepository _dictionaries;
  final BookMetadataExtractor _extractor;

  /// Build a zip containing all of [rootBookIds] together with — when
  /// [includeLinkedBooks] is true — every book reachable through the
  /// `book_links` graph (in either direction). Drops reading-progress
  /// fields when [includeProgress] is false. Writes the zip to the
  /// public `Download/` folder when accessible, otherwise to
  /// app-private docs; returns the absolute path.
  ///
  /// [filenameHint] is an optional human label (book title, series
  /// name, …) used in the output filename.
  Future<BookBundleResult> exportBundle({
    required List<int> rootBookIds,
    required bool includeLinkedBooks,
    required bool includeProgress,
    String? filenameHint,
    void Function(String stage)? onProgress,
  }) async {
    if (rootBookIds.isEmpty) {
      throw ArgumentError('rootBookIds must not be empty');
    }
    onProgress?.call('Resolving books');
    final rootBook = await _books.getById(rootBookIds.first);
    if (rootBook == null) {
      throw StateError('Root book not found');
    }
    final bookIds = <int>{...rootBookIds};
    if (includeLinkedBooks) {
      for (final id in rootBookIds) {
        bookIds.addAll(await _walkLinkedBooks(id));
      }
    }
    final orderedIds = [
      ...rootBookIds,
      ...bookIds.where((id) => !rootBookIds.contains(id)),
    ];

    onProgress?.call('Loading book metadata');
    final books = <Book>[];
    for (final id in orderedIds) {
      final b = await _books.getById(id);
      if (b != null) books.add(b);
    }
    final localIdByBookId = <int, int>{
      for (var i = 0; i < books.length; i++) books[i].id!: i,
    };

    onProgress?.call('Collecting citations');
    final citations = <Map<String, dynamic>>[];
    for (final book in books) {
      final all = (await _citations.getAll())
          .where((c) => c.bookId == book.id);
      for (final c in all) {
        citations.add({
          'book_local_id': localIdByBookId[book.id]!,
          'text': c.text,
          'chapter_index': c.chapterIndex,
          'char_start': c.charStart,
          'char_end': c.charEnd,
          'created_at': c.createdAt.millisecondsSinceEpoch,
        });
      }
    }

    onProgress?.call('Collecting notes');
    final notes = <Map<String, dynamic>>[];
    final allNotes = await _notes.getAll();
    for (final book in books) {
      for (final n in allNotes.where((n) => n.bookId == book.id)) {
        notes.add({
          'book_local_id': localIdByBookId[book.id]!,
          'selected_text': n.selectedText,
          'note_text': n.noteText,
          'chapter_index': n.chapterIndex,
          'char_start': n.charStart,
          'char_end': n.charEnd,
          'created_at': n.createdAt.millisecondsSinceEpoch,
          'updated_at': n.updatedAt.millisecondsSinceEpoch,
        });
      }
    }

    onProgress?.call('Collecting characters');
    final seriesSet = books
        .map((b) => b.series)
        .whereType<String>()
        .toSet();
    // Custom statuses are exported in full so the import side can
    // recreate them by name before any character or status entry
    // tries to reference them. They aren't series-scoped, so we
    // ship the whole table.
    final customStatusesJson = await _collectCustomStatusesJson();
    final affiliationsJson =
        await _collectAffiliationsJson(seriesSet);
    final charactersJson = await _collectCharactersJson(
      seriesSet,
      localIdByBookId,
    );
    final relationshipsJson =
        await _collectRelationshipsJson(seriesSet, localIdByBookId);

    onProgress?.call('Collecting dictionaries');
    final dictionariesJson = await _collectDictionariesJson(seriesSet);

    onProgress?.call('Collecting links');
    final linksJson = await _collectLinksJson(localIdByBookId);

    onProgress?.call('Reading book files');
    final archive = Archive();
    final booksJson = <Map<String, dynamic>>[];
    for (var i = 0; i < books.length; i++) {
      final book = books[i];
      final ext = p.extension(book.filePath);
      final bookEntry = await _addBookFile(archive, i, book, ext);
      bookEntry['local_id'] = i;
      if (!includeProgress) {
        bookEntry.remove('last_opened_at');
        bookEntry.remove('progress');
        bookEntry.remove('position');
      }
      booksJson.add(bookEntry);
    }

    onProgress?.call('Building manifest');
    final manifest = <String, dynamic>{
      // schema_version 2 adds custom_statuses, affiliations (with
      // parent hierarchy), relationships, character status timeline /
      // first-seen / spoiler triples, and description spoiler page.
      // Older bundles still import — every new field is optional.
      'schema_version': 2,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'app_db_version': DatabaseHelper.dbVersion,
      'root_local_id': 0,
      'include_progress': includeProgress,
      'books': booksJson,
      'citations': citations,
      'notes': notes,
      'custom_statuses': customStatusesJson,
      'affiliations': affiliationsJson,
      'characters': charactersJson,
      'relationships': relationshipsJson,
      'dictionaries': dictionariesJson,
      'book_links': linksJson,
    };
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );

    onProgress?.call('Compressing');
    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw StateError('ZipEncoder produced no bytes');
    }

    final filename = _suggestedFilename(filenameHint ?? rootBook.title);
    onProgress?.call('Writing file');
    final destPath = await _writeBundleBytes(filename, zipBytes);
    onProgress?.call('Done');
    return BookBundleResult(
      savedPath: destPath,
      bytes: zipBytes.length,
    );
  }

  /// Inspect a bundle without modifying anything — used by the import
  /// screen to show the user what's about to land in their library.
  Future<BundlePreview> previewBundle(String zipPath) async {
    final manifest = await _readManifest(zipPath);
    final books = (manifest['books'] as List).cast<Map<String, dynamic>>();
    final rootIndex = (manifest['root_local_id'] as num? ?? 0).toInt();
    final root = rootIndex < books.length ? books[rootIndex] : books.first;
    return BundlePreview(
      rootTitle: root['title']?.toString() ?? 'Untitled',
      bookCount: books.length,
      citationCount: (manifest['citations'] as List? ?? const []).length,
      noteCount: (manifest['notes'] as List? ?? const []).length,
      characterCount: (manifest['characters'] as List? ?? const []).length,
      dictionaryCount:
          (manifest['dictionaries'] as List? ?? const []).length,
      linkCount: (manifest['book_links'] as List? ?? const []).length,
      includesProgress: manifest['include_progress'] as bool? ?? false,
      bookTitles: books
          .map((b) => b['title']?.toString() ?? 'Untitled')
          .toList(),
      createdAt: manifest['created_at']?.toString(),
    );
  }

  Future<ImportSummary> importBundle(
    String zipPath, {
    void Function(String stage)? onProgress,
  }) async {
    onProgress?.call('Reading bundle');
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final manifestEntry = archive.findFile('manifest.json');
    if (manifestEntry == null) {
      throw const FormatException('Not a Lorekeeper bundle');
    }
    final manifest = jsonDecode(
      utf8.decode(manifestEntry.content as List<int>),
    ) as Map<String, dynamic>;

    final dbVersion =
        (manifest['app_db_version'] as num? ?? 0).toInt();
    if (dbVersion > DatabaseHelper.dbVersion) {
      throw FormatException(
        'Bundle was made with a newer app version '
        '(DB v$dbVersion vs. installed v${DatabaseHelper.dbVersion}). '
        'Update the app and try again.',
      );
    }

    final base = await getApplicationDocumentsDirectory();
    final libraryDir = Directory(p.join(base.path, 'library'));
    if (!await libraryDir.exists()) {
      await libraryDir.create(recursive: true);
    }

    onProgress?.call('Importing books');
    final booksList =
        (manifest['books'] as List).cast<Map<String, dynamic>>();
    final localIdToDbId = <int, int>{};
    var booksAdded = 0;
    var booksMerged = 0;
    for (final entry in booksList) {
      final localId = (entry['local_id'] as num).toInt();
      final existing = await _findExistingBook(entry);
      if (existing != null) {
        localIdToDbId[localId] = existing.id!;
        booksMerged++;
        continue;
      }
      final fileEntryName = entry['file'] as String?;
      String? destPath;
      if (fileEntryName != null) {
        final fileBytes = archive.findFile(fileEntryName)?.content;
        if (fileBytes is! List<int>) continue;
        final filename = '${entry['title']}'.replaceAll(
              RegExp(r'[\\/:*?"<>|]'),
              '_',
            ) +
            p.extension(fileEntryName);
        destPath = await _uniqueLibraryPath(libraryDir, filename);
        await File(destPath).writeAsBytes(fileBytes, flush: true);
      }
      if (destPath == null) continue;

      final coverEntryName = entry['cover'] as String?;
      String? coverPath;
      final book = Book(
        title: entry['title'] as String? ?? 'Untitled',
        author: entry['author'] as String?,
        filePath: destPath,
        format: BookFormat.fromExtension(
              p.extension(destPath).replaceAll('.', '').toLowerCase(),
            ) ??
            BookFormat.epub,
        fileSize: (entry['file_size'] as num?)?.toInt(),
        addedAt: DateTime.now(),
        description: entry['description'] as String?,
        series: entry['series'] as String?,
        seriesNumber: (entry['series_number'] as num?)?.toDouble(),
        progress: ((entry['progress'] as num?) ?? 0).toDouble(),
        position: (entry['position'] as Map?)?.cast<String, dynamic>(),
        lastOpenedAt: entry['last_opened_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                (entry['last_opened_at'] as num).toInt(),
              )
            : null,
      );
      final newId = await _books.insert(book);
      if (coverEntryName != null) {
        final coverBytes = archive.findFile(coverEntryName)?.content;
        if (coverBytes is List<int>) {
          coverPath = await _extractor.saveCover(
            newId,
            Uint8List.fromList(coverBytes),
          );
          final inserted = await _books.getById(newId);
          if (inserted != null) {
            await _books.update(inserted.copyWith(coverPath: coverPath));
          }
        }
      }
      localIdToDbId[localId] = newId;
      booksAdded++;
    }

    onProgress?.call('Importing citations');
    var citationsAdded = 0;
    for (final c in (manifest['citations'] as List? ?? const [])
        .cast<Map<String, dynamic>>()) {
      final bookId = localIdToDbId[(c['book_local_id'] as num).toInt()];
      if (bookId == null) continue;
      final exists = await _citationExists(
        bookId,
        (c['chapter_index'] as num?)?.toInt(),
        (c['char_start'] as num?)?.toInt(),
        (c['char_end'] as num?)?.toInt(),
      );
      if (exists) continue;
      await _citations.add(
        bookId: bookId,
        text: c['text'] as String,
        chapterIndex: (c['chapter_index'] as num?)?.toInt(),
        charStart: (c['char_start'] as num?)?.toInt(),
        charEnd: (c['char_end'] as num?)?.toInt(),
      );
      citationsAdded++;
    }

    onProgress?.call('Importing notes');
    var notesAdded = 0;
    for (final n in (manifest['notes'] as List? ?? const [])
        .cast<Map<String, dynamic>>()) {
      final bookId = localIdToDbId[(n['book_local_id'] as num).toInt()];
      if (bookId == null) continue;
      final exists = await _noteExists(
        bookId,
        (n['chapter_index'] as num?)?.toInt(),
        (n['char_start'] as num?)?.toInt(),
        (n['char_end'] as num?)?.toInt(),
      );
      if (exists) continue;
      await _notes.add(
        bookId: bookId,
        chapterIndex: (n['chapter_index'] as num?)?.toInt(),
        charStart: (n['char_start'] as num?)?.toInt(),
        charEnd: (n['char_end'] as num?)?.toInt(),
        selectedText: n['selected_text'] as String,
        noteText: n['note_text'] as String,
      );
      notesAdded++;
    }

    // Custom statuses must land first — characters / status entries
    // reference them by name and the import resolves to local ids.
    // Keyed by (name, series) so a status that exists both globally
    // and scoped to a series can coexist.
    onProgress?.call('Importing custom statuses');
    String customKey(String name, String? series) =>
        '${name.toLowerCase()}|${(series ?? '').toLowerCase()}';
    final customStatusIdByKey = <String, int>{};
    {
      final existing = await _characters.listCustomStatuses();
      for (final cs in existing) {
        customStatusIdByKey[customKey(cs.name, cs.series)] = cs.id!;
      }
      for (final entry in (manifest['custom_statuses'] as List? ?? const [])
          .cast<Map<String, dynamic>>()) {
        final name = entry['name'] as String;
        final series = entry['series'] as String?;
        if (customStatusIdByKey.containsKey(customKey(name, series))) {
          continue;
        }
        final id = await _characters.createCustomStatus(
          name: name,
          colorArgb: (entry['color'] as num).toInt(),
          series: series,
        );
        customStatusIdByKey[customKey(name, series)] = id;
      }
    }
    // Lookup a custom status by name, preferring a series-scoped row
    // matching the calling character's series, and falling back to the
    // global one. Returns null when nothing matches — the caller then
    // skips the custom-id pointer and the built-in placeholder applies.
    int? lookupCustom(String? name, String? series) {
      if (name == null) return null;
      final scoped = customStatusIdByKey[customKey(name, series)];
      if (scoped != null) return scoped;
      return customStatusIdByKey[customKey(name, null)];
    }

    // Affiliations are a tree — create rows first, then set parents
    // in a second pass so a child can refer to a parent that was
    // created later in the array.
    onProgress?.call('Importing affiliations');
    final affIdByKey = <String, int>{};
    String affKey(String name, String? series) =>
        '${name.toLowerCase()}|${(series ?? '').toLowerCase()}';
    final manifestAffiliations =
        (manifest['affiliations'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
    for (final a in manifestAffiliations) {
      final name = a['name'] as String;
      final series = a['series'] as String?;
      final all = await _characters.listAllAffiliations();
      final match = all.firstWhere(
        (existing) =>
            existing.name.toLowerCase() == name.toLowerCase() &&
            (existing.series ?? '').toLowerCase() ==
                (series ?? '').toLowerCase(),
        orElse: () => Affiliation(
          id: -1,
          name: name,
          series: series,
          createdAt: DateTime.now(),
        ),
      );
      if (match.id != -1) {
        affIdByKey[affKey(name, series)] = match.id!;
      } else {
        final id = await _characters.createAffiliation(
          name: name,
          series: series,
        );
        affIdByKey[affKey(name, series)] = id;
      }
    }
    for (final a in manifestAffiliations) {
      final parentName = a['parent_name'] as String?;
      if (parentName == null) continue;
      final parentSeries =
          (a['parent_series'] as String?) ?? a['series'] as String?;
      final id = affIdByKey[affKey(a['name'] as String, a['series'] as String?)];
      final parentId = affIdByKey[affKey(parentName, parentSeries)];
      if (id == null || parentId == null) continue;
      await _characters.setAffiliationParent(
        affiliationId: id,
        parentId: parentId,
      );
    }

    onProgress?.call('Importing characters');
    var charactersAdded = 0;
    var descriptionsAdded = 0;
    for (final c in (manifest['characters'] as List? ?? const [])
        .cast<Map<String, dynamic>>()) {
      final name = c['name'] as String;
      final series = c['series'] as String?;
      final existing =
          await _characters.findByName(name, series: series);
      final characterId = existing?.id ??
          await _characters.create(name: name, series: series);
      if (existing == null) charactersAdded++;

      // Default status — only update on first creation so we don't
      // clobber a value the user already set on the destination
      // device. New bundles carry both a built-in name and an
      // optional custom-status name; older bundles supply neither.
      if (existing == null) {
        final defaultStatusName = c['default_status'] as String?;
        final builtIn = CharacterStatus.fromName(defaultStatusName) ??
            CharacterStatus.alive;
        final defaultCustomName =
            c['default_custom_status_name'] as String?;
        final customId = lookupCustom(defaultCustomName, series);
        if (defaultStatusName != null || customId != null) {
          await _characters.setDefaultStatus(
            characterId: characterId,
            status: builtIn,
            customStatusId: customId,
          );
        }
        // First-seen anchor.
        final fsLocal = (c['first_seen_book_local_id'] as num?)?.toInt();
        final fsBookId =
            fsLocal != null ? localIdToDbId[fsLocal] : null;
        final fsChapter = (c['first_seen_chapter_index'] as num?)?.toInt();
        final fsPage =
            (c['first_seen_page_in_chapter'] as num?)?.toInt();
        if (fsBookId != null || fsChapter != null || fsPage != null) {
          await _characters.setFirstSeen(
            characterId: characterId,
            bookId: fsBookId,
            chapterIndex: fsChapter,
            pageInChapter: fsPage,
          );
        }
      }

      for (final alias in (c['aliases'] as List? ?? const [])
          .whereType<String>()) {
        try {
          await _characters.addAlias(
            characterId: characterId,
            alias: alias,
          );
        } catch (_) {/* already-exists, ignore */}
      }
      for (final affName in (c['affiliations'] as List? ?? const [])
          .whereType<String>()) {
        // Prefer the id from the top-level affiliations pass; fall
        // back to lookup-or-create for older bundles that didn't
        // include the affiliations array.
        var affId = affIdByKey[affKey(affName, series)] ??
            affIdByKey[affKey(affName, null)];
        if (affId == null) {
          final all = await _characters.listAffiliationsForSeries(series);
          final match = all
              .where((a) => a.name.toLowerCase() == affName.toLowerCase())
              .cast<Affiliation?>()
              .firstWhere((_) => true, orElse: () => null);
          affId = match?.id ??
              await _characters.createAffiliation(
                name: affName,
                series: series,
              );
          affIdByKey[affKey(affName, series)] = affId;
        }
        try {
          await _characters.linkAffiliation(
            characterId: characterId,
            affiliationId: affId,
          );
        } catch (_) {/* already linked */}
      }
      for (final d in (c['descriptions'] as List? ?? const [])
          .cast<Map<String, dynamic>>()) {
        final descBookLocal = (d['book_local_id'] as num?)?.toInt();
        final descBookId =
            descBookLocal != null ? localIdToDbId[descBookLocal] : null;
        final existingDescs =
            await _characters.descriptionsForCharacter(characterId);
        if (existingDescs.any((ed) => ed.text == d['text'])) continue;
        final spoilerBookLocal =
            (d['spoiler_book_local_id'] as num?)?.toInt();
        final spoilerBookId = spoilerBookLocal != null
            ? localIdToDbId[spoilerBookLocal]
            : null;
        await _characters.addDescription(
          characterId: characterId,
          text: d['text'] as String,
          bookId: descBookId,
          spoilerBookId: spoilerBookId,
          spoilerChapterIndex:
              (d['spoiler_chapter_index'] as num?)?.toInt(),
          spoilerPageInChapter:
              (d['spoiler_page_in_chapter'] as num?)?.toInt(),
        );
        descriptionsAdded++;
      }

      // Status timeline — only seeded on first import to avoid
      // duplicating entries when the user re-imports an updated
      // bundle. A simple created_at de-dupe inside listStatusEntries
      // would be more permissive but harder to reason about.
      if (existing == null) {
        for (final entry in (c['status_history'] as List? ?? const [])
            .cast<Map<String, dynamic>>()) {
          final builtIn =
              CharacterStatus.fromName(entry['status'] as String?) ??
                  CharacterStatus.alive;
          final customName = entry['custom_status_name'] as String?;
          final customId = lookupCustom(customName, series);
          final entryBookLocal =
              (entry['book_local_id'] as num?)?.toInt();
          final entryBookId = entryBookLocal != null
              ? localIdToDbId[entryBookLocal]
              : null;
          await _characters.addStatusEntry(
            characterId: characterId,
            status: builtIn,
            customStatusId: customId,
            bookId: entryBookId,
            chapterIndex: (entry['chapter_index'] as num?)?.toInt(),
            pageInChapter: (entry['page_in_chapter'] as num?)?.toInt(),
            note: entry['note'] as String?,
          );
        }
      }
    }

    // Relationships go after every character row exists so both
    // endpoints resolve. Bundle stores the forward edge only — the
    // repo writes the symmetric inverse automatically.
    onProgress?.call('Importing relationships');
    {
      final allChars = await _characters.listAll();
      final byKey = <String, int>{
        for (final ch in allChars)
          '${ch.name.toLowerCase()}|${(ch.series ?? '').toLowerCase()}':
              ch.id!,
      };
      String charKey(String name, String? series) =>
          '${name.toLowerCase()}|${(series ?? '').toLowerCase()}';
      for (final r in (manifest['relationships'] as List? ?? const [])
          .cast<Map<String, dynamic>>()) {
        final fromId = byKey[charKey(
          r['from_name'] as String,
          r['from_series'] as String?,
        )];
        final toId = byKey[charKey(
          r['to_name'] as String,
          r['to_series'] as String?,
        )];
        if (fromId == null || toId == null) continue;
        final spoilerBookLocal =
            (r['spoiler_book_local_id'] as num?)?.toInt();
        final spoilerBookId = spoilerBookLocal != null
            ? localIdToDbId[spoilerBookLocal]
            : null;
        await _characters.addRelationship(
          fromCharacterId: fromId,
          toCharacterId: toId,
          kind: RelationshipKind.fromName(r['kind'] as String),
          note: r['note'] as String?,
          spoilerBookId: spoilerBookId,
          spoilerChapterIndex:
              (r['spoiler_chapter_index'] as num?)?.toInt(),
          spoilerPageInChapter:
              (r['spoiler_page_in_chapter'] as num?)?.toInt(),
        );
      }
    }

    onProgress?.call('Importing dictionaries');
    var dictionaryEntriesAdded = 0;
    for (final dict in (manifest['dictionaries'] as List? ?? const [])
        .cast<Map<String, dynamic>>()) {
      final name = dict['name'] as String;
      final allDicts = await _dictionaries.listDictionaries();
      var existing = allDicts
          .where((d) => d.name.toLowerCase() == name.toLowerCase())
          .cast<Dictionary?>()
          .firstWhere((_) => true, orElse: () => null);
      int dictId;
      if (existing != null) {
        dictId = existing.id!;
      } else {
        dictId = await _dictionaries.createDictionary(
          name: name,
          description: dict['description'] as String?,
          series: dict['series'] as String?,
        );
      }
      final entries = await _dictionaries.entriesForDictionary(dictId);
      final existingByWord = {
        for (final e in entries) e.word.toLowerCase(): e,
      };
      for (final entry in (dict['entries'] as List? ?? const [])
          .cast<Map<String, dynamic>>()) {
        final word = entry['word'] as String;
        if (existingByWord.containsKey(word.toLowerCase())) continue;
        await _dictionaries.addEntry(
          dictionaryId: dictId,
          word: word,
          definition: entry['definition'] as String,
        );
        dictionaryEntriesAdded++;
      }
    }

    onProgress?.call('Importing links');
    var linksAdded = 0;
    for (final l in (manifest['book_links'] as List? ?? const [])
        .cast<Map<String, dynamic>>()) {
      final source =
          localIdToDbId[(l['source_local_id'] as num).toInt()];
      final target =
          localIdToDbId[(l['target_local_id'] as num).toInt()];
      if (source == null || target == null) continue;
      final exists = await _linkExists(
        source,
        target,
        (l['source_chapter_index'] as num?)?.toInt(),
        (l['source_char_start'] as num?)?.toInt(),
      );
      if (exists) continue;
      await _links.add(
        sourceBookId: source,
        sourceChapterIndex: (l['source_chapter_index'] as num?)?.toInt(),
        sourceCharStart: (l['source_char_start'] as num?)?.toInt(),
        sourceCharEnd: (l['source_char_end'] as num?)?.toInt(),
        targetBookId: target,
        label: l['label'] as String,
      );
      linksAdded++;
    }

    onProgress?.call('Done');
    return ImportSummary(
      booksAdded: booksAdded,
      booksMerged: booksMerged,
      citationsAdded: citationsAdded,
      notesAdded: notesAdded,
      charactersAdded: charactersAdded,
      descriptionsAdded: descriptionsAdded,
      dictionaryEntriesAdded: dictionaryEntriesAdded,
      linksAdded: linksAdded,
    );
  }

  // ====== helpers ======

  Future<Set<int>> _walkLinkedBooks(int rootBookId) async {
    final visited = <int>{rootBookId};
    final queue = <int>[rootBookId];
    while (queue.isNotEmpty) {
      final id = queue.removeLast();
      final outgoing = await _links.getBySourceBook(id);
      final incoming = await _links.getByTargetBook(id);
      for (final l in [...outgoing, ...incoming]) {
        final other = l.sourceBookId == id ? l.targetBookId : l.sourceBookId;
        if (visited.add(other)) queue.add(other);
      }
    }
    return visited;
  }

  Future<Map<String, dynamic>> _addBookFile(
    Archive archive,
    int localId,
    Book book,
    String ext,
  ) async {
    final bookFile = File(book.filePath);
    final fileEntry = <String, dynamic>{
      'title': book.title,
      'author': book.author,
      'description': book.description,
      'series': book.series,
      'series_number': book.seriesNumber,
      'format': book.format.name,
      'file_size': book.fileSize,
      'added_at': book.addedAt.millisecondsSinceEpoch,
      'last_opened_at': book.lastOpenedAt?.millisecondsSinceEpoch,
      'progress': book.progress,
      'position': book.position,
    };

    if (await bookFile.exists()) {
      final bytes = await bookFile.readAsBytes();
      final archivePath = 'books/$localId$ext';
      archive.addFile(
        ArchiveFile(archivePath, bytes.length, bytes),
      );
      fileEntry['file'] = archivePath;
    }
    final coverPath = book.coverPath;
    if (coverPath != null && await File(coverPath).exists()) {
      final coverBytes = await File(coverPath).readAsBytes();
      final coverArchivePath = 'books/$localId.jpg';
      archive.addFile(
        ArchiveFile(
          coverArchivePath,
          coverBytes.length,
          coverBytes,
        ),
      );
      fileEntry['cover'] = coverArchivePath;
    }
    return fileEntry;
  }

  Future<List<Map<String, dynamic>>> _collectCharactersJson(
    Set<String> seriesSet,
    Map<int, int> localIdByBookId,
  ) async {
    // Custom statuses are referenced from characters and history rows
    // by id; the bundle stores them by *name* so the import side can
    // remap to whatever id the destination DB ends up with.
    final customs = await _characters.listCustomStatuses();
    final customNameById = {
      for (final cs in customs) cs.id!: cs.name,
    };
    final result = <Map<String, dynamic>>[];
    final all = await _characters.listAll();
    for (final c in all) {
      if (c.series == null || !seriesSet.contains(c.series)) continue;
      final aliases = await _characters.aliasesForCharacter(c.id!);
      final affiliations =
          await _characters.affiliationsForCharacter(c.id!);
      final descriptions =
          await _characters.descriptionsForCharacter(c.id!);
      final statusEntries = await _characters.listStatusEntries(c.id!);
      result.add({
        'name': c.name,
        'series': c.series,
        'created_at': c.createdAt.millisecondsSinceEpoch,
        'updated_at': c.updatedAt.millisecondsSinceEpoch,
        // Default status — both built-in name and (optional) custom
        // status by name. The import side picks whichever is set.
        'default_status': c.status.name,
        'default_custom_status_name':
            c.statusCustomId != null ? customNameById[c.statusCustomId] : null,
        'first_seen_book_local_id': c.firstSeenBookId != null
            ? localIdByBookId[c.firstSeenBookId!]
            : null,
        'first_seen_chapter_index': c.firstSeenChapterIndex,
        'first_seen_page_in_chapter': c.firstSeenPageInChapter,
        'aliases': aliases,
        'affiliations': affiliations.map((a) => a.name).toList(),
        'descriptions': descriptions
            .map((d) => {
                  'text': d.text,
                  'book_local_id':
                      d.bookId != null ? localIdByBookId[d.bookId!] : null,
                  'spoiler_book_local_id': d.spoilerBookId != null
                      ? localIdByBookId[d.spoilerBookId!]
                      : null,
                  'spoiler_chapter_index': d.spoilerChapterIndex,
                  'spoiler_page_in_chapter': d.spoilerPageInChapter,
                  'created_at': d.createdAt.millisecondsSinceEpoch,
                })
            .toList(),
        'status_history': statusEntries
            .map((e) => {
                  'status': e.status.name,
                  'custom_status_name': e.customStatusId != null
                      ? customNameById[e.customStatusId]
                      : null,
                  'book_local_id': e.bookId != null
                      ? localIdByBookId[e.bookId!]
                      : null,
                  'chapter_index': e.chapterIndex,
                  'page_in_chapter': e.pageInChapter,
                  'note': e.note,
                  'created_at': e.createdAt.millisecondsSinceEpoch,
                })
            .toList(),
      });
    }
    return result;
  }

  /// Custom statuses can be global or scoped to a series — both are
  /// exported in full so the import side can recreate them with the
  /// same scope. De-duplication on import keys on (name, series).
  Future<List<Map<String, dynamic>>> _collectCustomStatusesJson() async {
    final all = await _characters.listCustomStatuses();
    return all
        .map((c) => {
              'name': c.name,
              'series': c.series,
              'color': c.colorArgb,
              'created_at': c.createdAt.millisecondsSinceEpoch,
            })
        .toList();
  }

  /// Affiliations belonging to any of [seriesSet] plus globals (so the
  /// hierarchy round-trips even when a sub-faction sits under a global
  /// parent). Stored by name + parent_name so the import side can
  /// rebuild the tree without depending on local DB ids.
  Future<List<Map<String, dynamic>>> _collectAffiliationsJson(
    Set<String> seriesSet,
  ) async {
    final all = await _characters.listAllAffiliations();
    final byId = {for (final a in all) a.id!: a};
    final scoped = all
        .where((a) => a.series == null || seriesSet.contains(a.series))
        .toList();
    return scoped
        .map((a) => {
              'name': a.name,
              'series': a.series,
              'parent_name': a.parentId != null
                  ? byId[a.parentId]?.name
                  : null,
              'parent_series': a.parentId != null
                  ? byId[a.parentId]?.series
                  : null,
              'created_at': a.createdAt.millisecondsSinceEpoch,
            })
        .toList();
  }

  /// Outgoing relationships between two in-scope characters. Stored
  /// by character (name, series) since DB ids don't translate. Only
  /// the forward edge of each pair is exported — the repo's
  /// `addRelationship` recreates the symmetric inverse on import.
  Future<List<Map<String, dynamic>>> _collectRelationshipsJson(
    Set<String> seriesSet,
    Map<int, int> localIdByBookId,
  ) async {
    final all = await _characters.allRelationships();
    final allChars = await _characters.listAll();
    final charsById = {for (final c in allChars) c.id!: c};
    final result = <Map<String, dynamic>>[];
    final emitted = <String>{}; // de-dupe symmetric inverses
    for (final r in all) {
      final from = charsById[r.fromCharacterId];
      final to = charsById[r.toCharacterId];
      if (from == null || to == null) continue;
      // Only carry edges that involve at least one in-scope series.
      final inScope = (from.series != null && seriesSet.contains(from.series)) ||
          (to.series != null && seriesSet.contains(to.series));
      if (!inScope) continue;
      // Drop the inverse edge — addRelationship recreates it.
      final pairKey = _relationshipPairKey(r, from, to);
      if (emitted.contains(pairKey)) continue;
      emitted.add(pairKey);
      result.add({
        'from_name': from.name,
        'from_series': from.series,
        'to_name': to.name,
        'to_series': to.series,
        'kind': r.kind.name,
        'note': r.note,
        'spoiler_book_local_id': r.spoilerBookId != null
            ? localIdByBookId[r.spoilerBookId!]
            : null,
        'spoiler_chapter_index': r.spoilerChapterIndex,
        'spoiler_page_in_chapter': r.spoilerPageInChapter,
        'created_at': r.createdAt.millisecondsSinceEpoch,
      });
    }
    return result;
  }

  /// Stable key for a relationship pair so we don't emit both sides of
  /// an automatic-inverse pair (e.g. parent ↔ child). Uses the kind
  /// plus a sorted endpoint pair so the inverse edge produces the
  /// same key.
  String _relationshipPairKey(
    CharacterRelationship r,
    Character from,
    Character to,
  ) {
    final aKey = '${from.name}|${from.series ?? ''}';
    final bKey = '${to.name}|${to.series ?? ''}';
    final endpoints = [aKey, bKey]..sort();
    final kindKey = [r.kind.name, r.kind.inverse.name]..sort();
    return '${kindKey.join('/')}::${endpoints.join('::')}';
  }

  Future<List<Map<String, dynamic>>> _collectDictionariesJson(
    Set<String> seriesSet,
  ) async {
    final result = <Map<String, dynamic>>[];
    final all = await _dictionaries.listDictionaries();
    for (final d in all) {
      if (d.series == null || !seriesSet.contains(d.series)) continue;
      final entries = await _dictionaries.entriesForDictionary(d.id!);
      result.add({
        'name': d.name,
        'description': d.description,
        'series': d.series,
        'created_at': d.createdAt.millisecondsSinceEpoch,
        'entries': entries
            .map((e) => {
                  'word': e.word,
                  'definition': e.definition,
                  'created_at': e.createdAt.millisecondsSinceEpoch,
                })
            .toList(),
      });
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _collectLinksJson(
    Map<int, int> localIdByBookId,
  ) async {
    final allLinks = await _links.getAll();
    return allLinks
        .where((l) =>
            localIdByBookId.containsKey(l.sourceBookId) &&
            localIdByBookId.containsKey(l.targetBookId))
        .map((l) => {
              'source_local_id': localIdByBookId[l.sourceBookId],
              'target_local_id': localIdByBookId[l.targetBookId],
              'label': l.label,
              'source_chapter_index': l.sourceChapterIndex,
              'source_char_start': l.sourceCharStart,
              'source_char_end': l.sourceCharEnd,
              'created_at': l.createdAt.millisecondsSinceEpoch,
            })
        .toList();
  }

  Future<Map<String, dynamic>> _readManifest(String zipPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final manifestEntry = archive.findFile('manifest.json');
    if (manifestEntry == null) {
      throw const FormatException('Not a Lorekeeper bundle');
    }
    return jsonDecode(utf8.decode(manifestEntry.content as List<int>))
        as Map<String, dynamic>;
  }

  Future<Book?> _findExistingBook(Map<String, dynamic> entry) async {
    final all = await _books.getAll();
    final title = (entry['title'] as String?)?.toLowerCase().trim();
    final author = (entry['author'] as String?)?.toLowerCase().trim();
    final size = (entry['file_size'] as num?)?.toInt();
    if (title == null) return null;
    return all
        .cast<Book?>()
        .firstWhere(
          (b) =>
              b!.title.toLowerCase().trim() == title &&
              (b.author?.toLowerCase().trim() ?? '') == (author ?? '') &&
              b.fileSize == size,
          orElse: () => null,
        );
  }

  Future<bool> _citationExists(
    int bookId,
    int? chapterIndex,
    int? charStart,
    int? charEnd,
  ) async {
    if (chapterIndex == null || charStart == null) return false;
    final existing =
        await _citations.getByBookAndChapter(bookId, chapterIndex);
    return existing.any(
      (c) => c.charStart == charStart && c.charEnd == charEnd,
    );
  }

  Future<bool> _noteExists(
    int bookId,
    int? chapterIndex,
    int? charStart,
    int? charEnd,
  ) async {
    if (chapterIndex == null || charStart == null) return false;
    final existing =
        await _notes.getByBookAndChapter(bookId, chapterIndex);
    return existing.any(
      (n) => n.charStart == charStart && n.charEnd == charEnd,
    );
  }

  Future<bool> _linkExists(
    int sourceId,
    int targetId,
    int? chapterIndex,
    int? charStart,
  ) async {
    final existing = await _links.getBySourceBook(sourceId);
    return existing.any(
      (l) =>
          l.targetBookId == targetId &&
          l.sourceChapterIndex == chapterIndex &&
          l.sourceCharStart == charStart,
    );
  }

  Future<String> _uniqueLibraryPath(
    Directory dir,
    String filename,
  ) async {
    final safe = filename.replaceAll(RegExp(r'[/\\]'), '_');
    final base = p.basenameWithoutExtension(safe);
    final ext = p.extension(safe);
    var candidate = p.join(dir.path, safe);
    var counter = 1;
    while (await File(candidate).exists()) {
      candidate = p.join(dir.path, '$base ($counter)$ext');
      counter++;
    }
    return candidate;
  }

  Future<String> _writeBundleBytes(
    String filename,
    List<int> bytes,
  ) async {
    const publicDownloads = '/storage/emulated/0/Download';
    final dir = Directory(publicDownloads);
    if (await dir.exists()) {
      try {
        final destPath = p.join(publicDownloads, filename);
        await File(destPath).writeAsBytes(bytes, flush: true);
        return destPath;
      } on FileSystemException {/* fall through */}
    }
    final base = await getApplicationDocumentsDirectory();
    final bundlesDir = Directory(p.join(base.path, 'bundles'));
    if (!await bundlesDir.exists()) {
      await bundlesDir.create(recursive: true);
    }
    final destPath = p.join(bundlesDir.path, filename);
    await File(destPath).writeAsBytes(bytes, flush: true);
    return destPath;
  }

  String _suggestedFilename(String label) {
    final clean = label
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final stem = clean.isEmpty ? 'book' : clean;
    return 'book-bundle-$stem-${_dateStamp()}.zip';
  }

  String _dateStamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${two(n.month)}-${two(n.day)}'
        '-${two(n.hour)}${two(n.minute)}';
  }
}
