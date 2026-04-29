import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/navigation/main_drawer.dart';
import '../domain/affiliation.dart';
import '../domain/character.dart';
import '../providers/character_provider.dart';
import 'character_timeline_screen.dart';
import 'widgets/character_affiliations_editor.dart';
import 'widgets/character_alias_editor.dart';
import 'widgets/character_description_card.dart';

class CharactersScreen extends ConsumerWidget {
  const CharactersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chars = ref.watch(charactersProvider);
    return Scaffold(
      drawer: const MainDrawer(currentRoute: '/characters'),
      appBar: AppBar(title: const Text('Characters')),
      body: chars.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) return const _EmptyState();
          // Group by series. Globals (series == null) go last under
          // "Other" so the more-specific series buckets surface first.
          final bySeries = <String?, List<Character>>{};
          for (final c in list) {
            (bySeries[c.series] ??= []).add(c);
          }
          final keys = bySeries.keys.toList()
            ..sort((a, b) {
              if (a == null && b == null) return 0;
              if (a == null) return 1; // nulls last
              if (b == null) return -1;
              return a.toLowerCase().compareTo(b.toLowerCase());
            });
          final theme = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              for (final series in keys)
                Theme(
                  // Hide the default ExpansionTile divider lines so the
                  // series group blends with its affiliation sub-groups.
                  data: theme.copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    initiallyExpanded: false,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                    childrenPadding: EdgeInsets.zero,
                    title: Text(
                      (series ?? 'Other').toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    children: [
                      _SeriesAffiliations(
                        series: series,
                        characters: bySeries[series]!,
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Within one series group, splits its characters into sub-groups by
/// affiliation. A character with multiple affiliations appears under
/// each one; characters with no affiliation go in an "Unaffiliated"
/// section at the bottom. Each sub-group is its own ExpansionTile so
/// it can be collapsed independently.
class _SeriesAffiliations extends ConsumerWidget {
  const _SeriesAffiliations({
    required this.series,
    required this.characters,
  });

  final String? series;
  final List<Character> characters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final affMap =
        ref.watch(affiliationsByCharacterForSeriesProvider(series));
    return affMap.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text('Error: $e'),
      data: (byChar) {
        // Build {affiliationId → (Affiliation, [characters])}
        // and also collect characters that have no affiliation.
        final byAffiliation = <int, _AffiliationGroup>{};
        final unaffiliated = <Character>[];
        for (final c in characters) {
          final ams = byChar[c.id] ?? const <Affiliation>[];
          if (ams.isEmpty) {
            unaffiliated.add(c);
            continue;
          }
          for (final a in ams) {
            final id = a.id!;
            final group = byAffiliation.putIfAbsent(
              id,
              () => _AffiliationGroup(affiliation: a),
            );
            group.characters.add(c);
          }
        }
        final groupKeys = byAffiliation.keys.toList()
          ..sort((a, b) => byAffiliation[a]!
              .affiliation
              .name
              .toLowerCase()
              .compareTo(
                byAffiliation[b]!.affiliation.name.toLowerCase(),
              ));

        Widget affiliationTile(_AffiliationGroup group) {
          return Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: false,
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              childrenPadding: EdgeInsets.zero,
              title: Text(
                group.affiliation.name,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                for (final c in group.characters) ...[
                  _CharacterCard(character: c),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final id in groupKeys) affiliationTile(byAffiliation[id]!),
            if (unaffiliated.isNotEmpty)
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: false,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                  childrenPadding: EdgeInsets.zero,
                  title: Text(
                    'Unaffiliated',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  children: [
                    for (final c in unaffiliated) ...[
                      _CharacterCard(character: c),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AffiliationGroup {
  _AffiliationGroup({required this.affiliation});
  final Affiliation affiliation;
  final List<Character> characters = [];
}

class _CharacterCard extends ConsumerWidget {
  const _CharacterCard({required this.character});

  final Character character;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final descs =
        ref.watch(descriptionsForCharacterProvider(character.id!));
    final aliases = ref.watch(aliasesForCharacterProvider(character.id!));
    return Card(
      child: ExpansionTile(
        subtitle: aliases.maybeWhen(
          data: (list) => list.isEmpty
              ? null
              : Text(
                  'a.k.a. ${list.join(', ')}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
          orElse: () => null,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                character.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (character.series != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  character.series!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.timeline),
              tooltip: 'View timeline',
              onPressed: character.id == null
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CharacterTimelineScreen(
                            character: character,
                          ),
                        ),
                      ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete character',
              onPressed: () => _confirmDelete(context, ref),
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          CharacterAliasEditor(character: character),
          const SizedBox(height: 12),
          CharacterAffiliationsEditor(character: character),
          const SizedBox(height: 16),
          descs.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => Text('Error: $e'),
            data: (list) {
              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No descriptions saved yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
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
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Delete "${character.name}"?'),
        content: const Text(
          'Removes the character and every saved description.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || character.id == null) return;
    await ref.read(charactersProvider.notifier).remove(character.id!);
    ref.read(characterRevisionProvider.notifier).state++;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_outline,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('No characters yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'In the reader, long-press a passage that describes a '
              'character and tap "Character".',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
