import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/character_repository.dart';
import '../domain/affiliation.dart';
import '../domain/character.dart';
import '../domain/character_description.dart';
import '../domain/character_relationship.dart';

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

/// All affiliations available in the given series (globals + matching).
/// Watched by the affiliation editor's picker dropdown.
final affiliationsForSeriesProvider =
    FutureProvider.family<List<Affiliation>, String?>((ref, series) {
  ref.watch(characterRevisionProvider);
  return ref
      .watch(characterRepositoryProvider)
      .listAffiliationsForSeries(series);
});

/// Affiliations linked to a single character.
final affiliationsForCharacterProvider =
    FutureProvider.family<List<Affiliation>, int>((ref, characterId) {
  ref.watch(characterRevisionProvider);
  return ref
      .watch(characterRepositoryProvider)
      .affiliationsForCharacter(characterId);
});

/// Map of character_id → affiliations within a series scope. Used by
/// the Characters screen to nest characters under affiliation
/// sub-groups inside their series group.
final affiliationsByCharacterForSeriesProvider = FutureProvider.family<
    Map<int, List<Affiliation>>, String?>((ref, series) {
  ref.watch(characterRevisionProvider);
  return ref
      .watch(characterRepositoryProvider)
      .affiliationsByCharacter(series);
});

/// Outgoing relationships for a single character — used by the
/// character sheet's relationships section.
final relationshipsForCharacterProvider =
    FutureProvider.family<List<CharacterRelationship>, int>(
  (ref, characterId) {
    ref.watch(characterRevisionProvider);
    return ref
        .watch(characterRepositoryProvider)
        .relationshipsFrom(characterId);
  },
);

/// Look up a character by id without scanning the full list at the
/// call site. Cached and refreshed by the revision counter.
final characterByIdProvider =
    FutureProvider.family<Character?, int>((ref, id) async {
  ref.watch(characterRevisionProvider);
  final all = await ref.watch(characterRepositoryProvider).listAll();
  for (final c in all) {
    if (c.id == id) return c;
  }
  return null;
});
