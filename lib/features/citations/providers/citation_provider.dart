import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/citation_repository.dart';
import '../domain/citation.dart';

final citationRepositoryProvider =
    Provider<CitationRepository>((_) => CitationRepository());

final citationsProvider =
    AsyncNotifierProvider<CitationsNotifier, List<Citation>>(
  CitationsNotifier.new,
);

class CitationsNotifier extends AsyncNotifier<List<Citation>> {
  @override
  Future<List<Citation>> build() async {
    return ref.watch(citationRepositoryProvider).getAll();
  }

  Future<int> add({
    int? bookId,
    required String text,
    int? chapterIndex,
    int? charStart,
    int? charEnd,
  }) async {
    final id = await ref.read(citationRepositoryProvider).add(
          bookId: bookId,
          text: text,
          chapterIndex: chapterIndex,
          charStart: charStart,
          charEnd: charEnd,
        );
    ref.invalidateSelf();
    return id;
  }

  Future<void> remove(int id) async {
    await ref.read(citationRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }
}
