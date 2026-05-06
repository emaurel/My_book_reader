import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/character_repository.dart';
import '../domain/affiliation.dart';
import '../domain/character.dart';
import '../domain/character_description.dart';
import '../domain/character_relationship.dart';
import '../domain/character_status_entry.dart';
import '../domain/custom_status.dart';
import '../presentation/widgets/character_status_indicator.dart';
import '../services/spoiler_position.dart';
import '../../library/providers/library_provider.dart';
import '../../reader/providers/reader_position_provider.dart';

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
    // Watch the revision counter so any in-app mutation (status,
    // alias, description, relationship, …) automatically re-fetches
    // the list and the row's status dot / metadata refresh live.
    ref.watch(characterRevisionProvider);
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

/// Status timeline entries for a character. Sorted by createdAt; the
/// resolver re-sorts by anchor for actual look-ups.
final statusEntriesForCharacterProvider =
    FutureProvider.family<List<CharacterStatusEntry>, int>(
  (ref, characterId) {
    ref.watch(characterRevisionProvider);
    return ref
        .watch(characterRepositoryProvider)
        .listStatusEntries(characterId);
  },
);

/// Resolved status of a character at the reader's current position —
/// returns both the built-in enum and the optional custom-status id
/// so the renderer can apply the right color/label.
final resolvedStatusForCharacterProvider =
    FutureProvider.family<ResolvedStatus, int>(
  (ref, characterId) async {
    ref.watch(characterRevisionProvider);
    final position = ref.watch(currentReaderPositionProvider);
    final repo = ref.watch(characterRepositoryProvider);
    final character = await ref.watch(characterByIdProvider(characterId).future);
    if (character == null) {
      return const ResolvedStatus(status: CharacterStatus.alive);
    }
    final entries = await repo.listStatusEntries(characterId);
    final cache = BookMetadataCache(ref.read(bookRepositoryProvider));
    return resolveStatusAt(
      character: character,
      entries: entries,
      position: position,
      books: cache,
    );
  },
);

/// High-level convenience: returns a fully-resolved [StatusDisplay]
/// for a character at the reader's current position. UI callers can
/// watch this and feed `display.color` / `display.label` directly to
/// the dot widget without managing customs themselves.
final statusDisplayForCharacterProvider =
    FutureProvider.family<StatusDisplay, int>(
  (ref, characterId) async {
    final resolved =
        await ref.watch(resolvedStatusForCharacterProvider(characterId).future);
    final customs = await ref.watch(customStatusesProvider.future);
    return statusDisplayFor(
      builtIn: resolved.status,
      customId: resolved.customStatusId,
      customs: customs,
    );
  },
);

/// True when the character's first-appearance anchor is past the
/// reader's current position. Used by the Characters screen to mask
/// out unencountered characters as "Hidden character" placeholders.
final isCharacterHiddenForReaderProvider =
    FutureProvider.family<bool, int>(
  (ref, characterId) async {
    ref.watch(characterRevisionProvider);
    final position = ref.watch(currentReaderPositionProvider);
    if (position == null) return false;
    final character = await ref.watch(characterByIdProvider(characterId).future);
    if (character == null) return false;
    final cache = BookMetadataCache(ref.read(bookRepositoryProvider));
    return isFirstSeenAhead(
      character: character,
      position: position,
      books: cache,
    );
  },
);

/// Set of character ids whose first-seen anchor is past the reader.
/// The Characters screen watches this once and filters at the list
/// level instead of waiting on a future per row.
final hiddenCharacterIdsForReaderProvider =
    FutureProvider<Set<int>>((ref) async {
  ref.watch(characterRevisionProvider);
  final position = ref.watch(currentReaderPositionProvider);
  if (position == null) return const <int>{};
  final repo = ref.watch(characterRepositoryProvider);
  final all = await repo.listAll();
  final cache = BookMetadataCache(ref.read(bookRepositoryProvider));
  final out = <int>{};
  for (final c in all) {
    if (c.id == null) continue;
    final hidden = await isFirstSeenAhead(
      character: c,
      position: position,
      books: cache,
    );
    if (hidden) out.add(c.id!);
  }
  return out;
});

/// User-controlled override that reveals every character regardless of
/// first-seen anchor. Toggled from the Characters screen's app bar so
/// the user can audit their own database.
final revealHiddenCharactersProvider = StateProvider<bool>((_) => false);

/// Every user-defined custom status — used for display lookups (a
/// saved entry might point at a custom row from any series, and we
/// need to be able to render it whoever is looking).
final customStatusesProvider =
    FutureProvider<List<CustomStatus>>((ref) {
  ref.watch(characterRevisionProvider);
  return ref.watch(characterRepositoryProvider).listCustomStatuses();
});

/// Custom statuses *available to pick* for a character in [series]:
/// globals plus matching-series rows. Drives the chip picker. Display
/// lookups still go via [customStatusesProvider] above.
final customStatusesForScopeProvider =
    FutureProvider.family<List<CustomStatus>, String?>((ref, series) {
  ref.watch(characterRevisionProvider);
  return ref
      .watch(characterRepositoryProvider)
      .listCustomStatusesForScope(series);
});
