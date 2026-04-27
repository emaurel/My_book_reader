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
    final charactersJson = await _collectCharactersJson(
      seriesSet,
      localIdByBookId,
    );

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
      'schema_version': 1,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'app_db_version': DatabaseHelper.dbVersion,
      'root_local_id': 0,
      'include_progress': includeProgress,
      'books': booksJson,
      'citations': citations,
      'notes': notes,
      'characters': charactersJson,
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
      throw const FormatException('Not a Book Reader bundle');
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
        final all = await _characters.listAffiliationsForSeries(series);
        var aff = all.firstWhere(
          (a) => a.name.toLowerCase() == affName.toLowerCase(),
          orElse: () => Affiliation(
            id: -1,
            name: affName,
            series: series,
            createdAt: DateTime.now(),
          ),
        );
        if (aff.id == -1) {
          final id =
              await _characters.createAffiliation(name: affName, series: series);
          aff = Affiliation(
            id: id,
            name: affName,
            series: series,
            createdAt: DateTime.now(),
          );
        }
        try {
          await _characters.linkAffiliation(
            characterId: characterId,
            affiliationId: aff.id!,
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
        await _characters.addDescription(
          characterId: characterId,
          text: d['text'] as String,
          bookId: descBookId,
        );
        descriptionsAdded++;
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
    final result = <Map<String, dynamic>>[];
    final all = await _characters.listAll();
    for (final c in all) {
      if (c.series == null || !seriesSet.contains(c.series)) continue;
      final aliases = await _characters.aliasesForCharacter(c.id!);
      final affiliations =
          await _characters.affiliationsForCharacter(c.id!);
      final descriptions =
          await _characters.descriptionsForCharacter(c.id!);
      result.add({
        'name': c.name,
        'series': c.series,
        'created_at': c.createdAt.millisecondsSinceEpoch,
        'updated_at': c.updatedAt.millisecondsSinceEpoch,
        'aliases': aliases,
        'affiliations': affiliations.map((a) => a.name).toList(),
        'descriptions': descriptions
            .map((d) => {
                  'text': d.text,
                  'book_local_id':
                      d.bookId != null ? localIdByBookId[d.bookId!] : null,
                  'created_at': d.createdAt.millisecondsSinceEpoch,
                })
            .toList(),
      });
    }
    return result;
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
      throw const FormatException('Not a Book Reader bundle');
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
