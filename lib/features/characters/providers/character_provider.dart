import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/character_repository.dart';
import '../domain/character.dart';
import '../domain/character_description.dart';

final characterRepositoryProvider =
    Provider<CharacterRepository>((_) => CharacterRepository());

/// Global list of all characters (for the management screen).
final charactersProvider =
    AsyncNotifierProvider<CharactersNotifier, List<Character>>(
  CharactersNotifier.new,
);

class CharactersNotifier extends AsyncNotifier<List<Character>> {
  @override
  Future<List<Character>> build() {
    return ref.watch(characterRepositoryProvider).listAll();
  }

  Future<int> create({required String name, String? series}) async {
    final id = await ref
        .read(characterRepositoryProvider)
        .create(name: name, series: series);
    ref.invalidateSelf();
    return id;
  }

  Future<void> remove(int id) async {
    await ref.read(characterRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }
}

/// Increments whenever a character or description changes — drives
/// re-paint of underlines in the EPUB viewer.
final characterRevisionProvider = StateProvider<int>((_) => 0);

/// Characters valid in a given series context (global + matching).
/// Used both by the EPUB viewer (to decide which names to underline)
/// and by the "Add description" sheet's picker.
final charactersForSeriesProvider =
    FutureProvider.family<List<Character>, String?>((ref, series) {
  ref.watch(characterRevisionProvider);
  return ref.watch(characterRepositoryProvider).listForSeries(series);
});

/// All descriptions for a character (joined nothing — just the rows).
final descriptionsForCharacterProvider = FutureProvider.family<
    List<CharacterDescription>, int>((ref, characterId) {
  ref.watch(characterRevisionProvider);
  return ref
      .watch(characterRepositoryProvider)
      .descriptionsForCharacter(characterId);
});

/// Aliases for a single character, sorted alphabetically.
final aliasesForCharacterProvider =
    FutureProvider.family<List<String>, int>((ref, characterId) {
  ref.watch(characterRevisionProvider);
  return ref
      .watch(characterRepositoryProvider)
      .aliasesForCharacter(characterId);
});
