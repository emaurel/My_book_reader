import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dictionary_repository.dart';
import '../domain/dictionary.dart';
import '../domain/dictionary_entry.dart';

final dictionaryRepositoryProvider =
    Provider<DictionaryRepository>((_) => DictionaryRepository());

/// All user-defined dictionaries.
final dictionariesProvider =
    AsyncNotifierProvider<DictionariesNotifier, List<Dictionary>>(
  DictionariesNotifier.new,
);

class DictionariesNotifier extends AsyncNotifier<List<Dictionary>> {
  @override
  Future<List<Dictionary>> build() {
    return ref.watch(dictionaryRepositoryProvider).listDictionaries();
  }

  Future<int> create({
    required String name,
    String? description,
    String? series,
  }) async {
    final id = await ref.read(dictionaryRepositoryProvider).createDictionary(
          name: name,
          description: description,
          series: series,
        );
    ref.invalidateSelf();
    return id;
  }

  Future<void> remove(int id) async {
    await ref.read(dictionaryRepositoryProvider).deleteDictionary(id);
    ref.invalidateSelf();
  }
}

/// Increments whenever any dictionary entry is added/removed/edited.
/// The EPUB viewer watches this to know when to re-paint underlines.
final dictionaryEntriesRevisionProvider = StateProvider<int>((_) => 0);

class WordEntry {
  WordEntry({required this.entry, required this.dictionaryName});
  final DictionaryEntry entry;
  final String? dictionaryName;
}

/// Family argument for [entriesForWordProvider]. `series` filters out
/// dictionaries that don't apply in the current book's context.
typedef WordLookup = ({String word, String? series});

final entriesForWordProvider =
    FutureProvider.family<List<WordEntry>, WordLookup>((ref, args) async {
  ref.watch(dictionaryEntriesRevisionProvider);
  final repo = ref.watch(dictionaryRepositoryProvider);
  final entries = await repo.entriesForWord(args.word, series: args.series);
  final dicts = await repo.listDictionaries();
  final nameById = {for (final d in dicts) d.id: d.name};
  return [
    for (final e in entries)
      WordEntry(entry: e, dictionaryName: nameById[e.dictionaryId]),
  ];
});

/// Entries belonging to a single dictionary. Re-runs when the revision
/// counter changes so card-driven edits/deletes propagate.
final entriesForDictionaryProvider = FutureProvider.family<
    List<DictionaryEntry>, int>((ref, dictionaryId) {
  ref.watch(dictionaryEntriesRevisionProvider);
  return ref
      .watch(dictionaryRepositoryProvider)
      .entriesForDictionary(dictionaryId);
});
