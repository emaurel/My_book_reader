import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/book_repository.dart';
import '../domain/book.dart';
import '../services/book_metadata_extractor.dart';
import '../services/book_scanner.dart';
import '../services/file_importer.dart';

final bookRepositoryProvider = Provider<BookRepository>((_) => BookRepository());
final fileImporterProvider = Provider<FileImporter>((_) => FileImporter());
final bookScannerProvider = Provider<BookScanner>((_) => BookScanner());
final metadataExtractorProvider =
    Provider<BookMetadataExtractor>((_) => BookMetadataExtractor());

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

final libraryProvider =
    AsyncNotifierProvider<LibraryNotifier, List<Book>>(LibraryNotifier.new);

class LibraryNotifier extends AsyncNotifier<List<Book>> {
  @override
  Future<List<Book>> build() async {
    final sort = ref.watch(librarySortProvider);
    final repo = ref.watch(bookRepositoryProvider);
    return repo.getAll(orderBy: sort.orderBy);
  }

  Future<int> importFromPicker() async {
    final importer = ref.read(fileImporterProvider);
    final repo = ref.read(bookRepositoryProvider);

    final imported = await importer.pickAndImport();
    var added = 0;

    for (final file in imported) {
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

  Future<int> scanDevice() async {
    final scanner = ref.read(bookScannerProvider);
    final repo = ref.read(bookRepositoryProvider);

    final granted = await scanner.ensureAccess();
    if (!granted) throw const ScanPermissionDeniedException();

    final files = await scanner.scan();
    var added = 0;
    for (final f in files) {
      final existing = await repo.getByPath(f.path);
      if (existing != null) continue;
      final id = await repo.insert(
        Book(
          title: f.title,
          filePath: f.path,
          format: f.format,
          fileSize: f.sizeBytes,
          addedAt: DateTime.now(),
        ),
      );
      await _hydrateMetadata(id, f.path, f.format);
      added++;
    }

    if (added > 0) ref.invalidateSelf();
    return added;
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
