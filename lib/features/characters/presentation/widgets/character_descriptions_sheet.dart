import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/character.dart';
import '../../providers/character_provider.dart';
import 'character_affiliations_editor.dart';
import 'character_alias_editor.dart';
import 'character_description_card.dart';

/// Sheet shown when an underlined character name is tapped. Lists every
/// saved description for that character; lets the user manage aliases
/// and edit/delete each description inline.
Future<void> showCharacterDescriptionsSheet(
  BuildContext context, {
  required String name,
  int? characterId,
  String? bookSeries,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetCtx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom,
      ),
      child: _CharacterDescriptionsSheet(
        tappedName: name,
        characterId: characterId,
        bookSeries: bookSeries,
      ),
    ),
  );
}

class _CharacterDescriptionsSheet extends ConsumerWidget {
  const _CharacterDescriptionsSheet({
    required this.tappedName,
    this.characterId,
    this.bookSeries,
  });
  final String tappedName;
  final int? characterId;
  final String? bookSeries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fut = _resolveCharacter(ref);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: FutureBuilder<Character?>(
          future: fut,
          builder: (_, snap) {
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final character = snap.data;
            if (character == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tappedName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text('No descriptions for this character.'),
                ],
              );
            }
            return _CharacterBody(character: character);
          },
        ),
      ),
    );
  }

  Future<Character?> _resolveCharacter(WidgetRef ref) async {
    final repo = ref.read(characterRepositoryProvider);
    if (characterId != null) {
      final all = await repo.listAll();
      for (final c in all) {
        if (c.id == characterId) return c;
      }
    }
    return repo.findByNameOrAlias(tappedName, series: bookSeries);
  }
}

class _CharacterBody extends ConsumerWidget {
  const _CharacterBody({required this.character});
  final Character character;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final descs =
        ref.watch(descriptionsForCharacterProvider(character.id!));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          character.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        CharacterAliasEditor(character: character),
        const SizedBox(height: 12),
        CharacterAffiliationsEditor(character: character),
        const SizedBox(height: 16),
        descs.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Error: $e'),
          data: (list) {
            if (list.isEmpty) {
              return Text(
                'No descriptions saved yet.',
                style: theme.textTheme.bodyMedium,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final d in list)
                  CharacterDescriptionCard(
                    key: ValueKey(d.id),
                    description: d,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
