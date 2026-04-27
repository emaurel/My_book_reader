import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/book_link_repository.dart';
import '../domain/book_link.dart';

final bookLinkRepositoryProvider =
    Provider<BookLinkRepository>((_) => BookLinkRepository());

final bookLinksProvider =
    AsyncNotifierProvider<BookLinksNotifier, List<BookLink>>(
  BookLinksNotifier.new,
);

class BookLinksNotifier extends AsyncNotifier<List<BookLink>> {
  @override
  Future<List<BookLink>> build() async {
    return ref.watch(bookLinkRepositoryProvider).getAll();
  }

  Future<int> add({
    required int sourceBookId,
    int? sourceChapterIndex,
    int? sourceCharStart,
    int? sourceCharEnd,
    required int targetBookId,
    required String label,
  }) async {
    final id = await ref.read(bookLinkRepositoryProvider).add(
          sourceBookId: sourceBookId,
          sourceChapterIndex: sourceChapterIndex,
          sourceCharStart: sourceCharStart,
          sourceCharEnd: sourceCharEnd,
          targetBookId: targetBookId,
          label: label,
        );
    ref.invalidateSelf();
    return id;
  }

  Future<void> remove(int id) async {
    await ref.read(bookLinkRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }
}
