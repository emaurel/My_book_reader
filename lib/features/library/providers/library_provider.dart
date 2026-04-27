import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../main.dart';
import '../data/book_repository.dart';
import '../domain/book.dart';
import '../services/book_metadata_extractor.dart';
import '../services/book_scanner.dart';
import '../services/file_importer.dart';
import '../services/kindle_converter.dart';

final bookRepositoryProvider = Provider<BookRepository>((_) => BookRepository());
final fileImporterProvider = Provider<FileImporter>((_) => FileImporter());
final bookScannerProvider = Provider<BookScanner>((_) => BookScanner());
final metadataExtractorProvider =
    Provider<BookMetadataExtractor>((_) => BookMetadataExtractor());
final kindleConverterProvider =
    Provider<KindleConverter>((_) => KindleConverter());

enum LibrarySort { recentlyAdded, recentlyOpened, title, author }

extension LibrarySortLabel on LibrarySort {
  String get label {
    switch (this) {
      case LibrarySort.recentlyAdded:
        return 'Recently added';
      case LibrarySort.recentlyOpened:
        return 'Recently opened';
      case LibrarySort.title:
        return 'Title';
      case LibrarySort.author:
        return 'Author';
    }
  }

  String get orderBy {
    switch (this) {
      case LibrarySort.recentlyAdded:
        return 'added_at DESC';
      case LibrarySort.recentlyOpened:
        return 'last_opened_at DESC NULLS LAST, added_at DESC';
      case LibrarySort.title:
        return 'title COLLATE NOCASE ASC';
      case LibrarySort.author:
        return 'author COLLATE NOCASE ASC, title COLLATE NOCASE ASC';
    }
  }
}

final librarySortProvider =
    StateProvider<LibrarySort>((_) => LibrarySort.recentlyAdded);

/// Books the user has started but not yet finished. Recomputed off the
/// main library list so that progress updates flow through.
final currentReadingsProvider = FutureProvider<List<Book>>((ref) async {
  // Watch the main library so that adding/removing/refreshing a book
  // invalidates this list too.
  await ref.watch(libraryProvider.future);
  return ref.read(bookRepositoryProvider).getCurrentReadings();
});

const _showDocumentsKey = 'library.showDocuments';

/// When false (default), the library hides PDF and TXT files and the
/// device scanner skips them. Toggled from the settings screen.
final showDocumentsProvider =
    StateNotifierProvider<ShowDocumentsNotifier, bool>((ref) {
  return ShowDocumentsNotifier(ref.watch(sharedPreferencesProvider));
});

class ShowDocumentsNotifier extends StateNotifier<bool> {
  ShowDocumentsNotifier(this._prefs)
      : super(_prefs.getBool(_showDocumentsKey) ?? false);

  final SharedPreferences _prefs;

  Future<void> set(bool v) async {
    state = v;
    await _prefs.setBool(_showDocumentsKey, v);
  }
}

bool _isBookFormat(BookFormat f) =>
    f == BookFormat.epub || f == BookFormat.azw;

final libraryProvider =
    AsyncNotifierProvider<LibraryNotifier, List<Book>>(LibraryNotifier.new);

class LibraryNotifier extends AsyncNotifier<List<Book>> {
  @override
  Future<List<Book>> build() async {
    final sort = ref.watch(librarySortProvider);
    final showDocs = ref.watch(showDocumentsProvider);
    final repo = ref.watch(bookRepositoryProvider);
    final all = await repo.getAll(orderBy: sort.orderBy);
    if (showDocs) return all;
    return all.where((b) => _isBookFormat(b.format)).toList();
  }

  Future<int> importFromPicker() async {
    final importer = ref.read(fileImporterProvider);
    final repo = ref.read(bookRepositoryProvider);

    final imported = await importer.pickAndImport();
    var added = 0;

    for (final raw in imported) {
      final file = await _maybeConvertKindle(
        path: raw.path,
        title: raw.title,
        format: raw.format,
        sizeBytes: raw.sizeBytes,
      );

      final existing = await repo.getByPath(file.path);
      if (existing != null) continue;

      final id = await repo.insert(
        Book(
          title: file.title,
          filePath: file.path,
          format: file.format,
          fileSize: file.sizeBytes,
          addedAt: DateTime.now(),
        ),
      );
      await _hydrateMetadata(id, file.path, file.format);
      added++;
    }

    if (added > 0) ref.invalidateSelf();
    return added;
  }

  /// Register a file that's already on disk in `app_documents/library/`
  /// (e.g. dropped there by the Anna's Archive download interceptor).
  /// Runs the same Kindle-conversion + metadata hydration as the picker
  /// flow. Returns true if a new book was added, false if the file's
  /// already in the library or its format is unsupported.
  Future<bool> addFromFile(String filePath) async {
    final repo = ref.read(bookRepositoryProvider);
    final ext =
        p.extension(filePath).replaceAll('.', '').toLowerCase();
    final format = BookFormat.fromExtension(ext);
    if (format == null) return false;

    final size = await File(filePath).length();
    final title = p.basenameWithoutExtension(filePath);

    final file = await _maybeConvertKindle(
      path: filePath,
      title: title,
      format: format,
      sizeBytes: size,
    );

    final existing = await repo.getByPath(file.path);
    if (existing != null) return false;

    final converted = file.format != format;
    final id = await repo.insert(
      Book(
        title: file.title,
        filePath: file.path,
        format: file.format,
        fileSize: file.sizeBytes,
        addedAt: DateTime.now(),
        originalPath: converted ? filePath : null,
      ),
    );
    await _hydrateMetadata(id, file.path, file.format);
    ref.invalidateSelf();
    return true;
  }

  Future<int> scanDevice() async {
    final scanner = ref.read(bookScannerProvider);
    final repo = ref.read(bookRepositoryProvider);

    final granted = await scanner.ensureAccess();
    if (!granted) throw const ScanPermissionDeniedException();

    final allFiles = await scanner.scan();
    final showDocs = ref.read(showDocumentsProvider);
    final files = showDocs
        ? allFiles
        : allFiles.where((f) => _isBookFormat(f.format)).toList();
    var added = 0;
    for (final raw in files) {
      // Dedupe against the source path *before* converting, so AZW3s
      // that were converted to EPUB on a previous scan don't get
      // re-converted now.
      final existingBySource = await repo.getBySourcePath(raw.path);
      if (existingBySource != null) continue;

      final f = await _maybeConvertKindle(
        path: raw.path,
        title: raw.title,
        format: raw.format,
        sizeBytes: raw.sizeBytes,
      );

      final existing = await repo.getByPath(f.path);
      if (existing != null) continue;
      final converted = f.format != raw.format;
      final id = await repo.insert(
        Book(
          title: f.title,
          filePath: f.path,
          format: f.format,
          fileSize: f.sizeBytes,
          addedAt: DateTime.now(),
          originalPath: converted ? raw.path : null,
        ),
      );
      await _hydrateMetadata(id, f.path, f.format);
      added++;
    }

    if (added > 0) ref.invalidateSelf();
    return added;
  }

  /// For Kindle formats (AZW / AZW3 / MOBI), convert to EPUB via
  /// `kindle_unpack` and return the EPUB-as-EPUB. Other formats pass
  /// through. If conversion fails the book is left as AZW so the
  /// placeholder reader explains the situation.
  Future<_PendingBook> _maybeConvertKindle({
    required String path,
    required String title,
    required BookFormat format,
    required int sizeBytes,
  }) async {
    if (format != BookFormat.azw) {
      return _PendingBook(
        path: path,
        title: title,
        format: format,
        sizeBytes: sizeBytes,
      );
    }
    final converter = ref.read(kindleConverterProvider);
    final converted = await converter.convert(path);
    if (converted == null) {
      return _PendingBook(
        path: path,
        title: title,
        format: format,
        sizeBytes: sizeBytes,
      );
    }
    return _PendingBook(
      path: converted.epubPath,
      title: converted.title,
      format: BookFormat.epub,
      sizeBytes: converted.sizeBytes,
    );
  }

  Future<void> _hydrateMetadata(
    int id,
    String path,
    BookFormat format,
  ) async {
    final extractor = ref.read(metadataExtractorProvider);
    final repo = ref.read(bookRepositoryProvider);
    try {
      final meta = await extractor.extract(path, format);
      String? coverPath;
      if (meta.coverBytes != null) {
        coverPath = await extractor.saveCover(id, meta.coverBytes!);
      }

      final book = await repo.getById(id);
      if (book == null) return;

      final newTitle = meta.title?.trim();
      await repo.update(book.copyWith(
        title: (newTitle != null && newTitle.isNotEmpty) ? newTitle : null,
        author: meta.author,
        description: meta.description,
        series: meta.series,
        seriesNumber: meta.seriesNumber,
        coverPath: coverPath,
      ));
    } catch (_) {
      // Metadata extraction failures are non-fatal — book stays in the
      // library with filename-based title and no cover.
    }
  }

  /// Re-runs metadata extraction for every book currently lacking a cover.
  /// Useful after the extractor was added to backfill the existing library.
  Future<int> refreshAllMetadata() async {
    final repo = ref.read(bookRepositoryProvider);
    final books = await repo.getAll();
    var refreshed = 0;
    for (final book in books) {
      if (book.id == null) continue;
      if (book.coverPath != null) continue;
      await _hydrateMetadata(book.id!, book.filePath, book.format);
      refreshed++;
    }
    if (refreshed > 0) ref.invalidateSelf();
    return refreshed;
  }

  Future<void> remove(int id) async {
    await ref.read(bookRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }

  Future<void> refresh() async => ref.invalidateSelf();
}

class _PendingBook {
  _PendingBook({
    required this.path,
    required this.title,
    required this.format,
    required this.sizeBytes,
  });

  final String path;
  final String title;
  final BookFormat format;
  final int sizeBytes;
}
