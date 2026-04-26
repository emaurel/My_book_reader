import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/book_repository.dart';
import '../domain/book.dart';
import '../services/file_importer.dart';

final bookRepositoryProvider = Provider<BookRepository>((_) => BookRepository());
final fileImporterProvider = Provider<FileImporter>((_) => FileImporter());

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

      await repo.insert(
        Book(
          title: file.title,
          filePath: file.path,
          format: file.format,
          fileSize: file.sizeBytes,
          addedAt: DateTime.now(),
        ),
      );
      added++;
    }

    if (added > 0) ref.invalidateSelf();
    return added;
  }

  Future<void> remove(int id) async {
    await ref.read(bookRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }

  Future<void> refresh() async => ref.invalidateSelf();
}
