import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/navigation/main_drawer.dart';
import '../../library/domain/book.dart';
import '../../library/providers/library_provider.dart';
import '../domain/affiliation.dart';
import '../domain/character.dart';
import '../providers/character_provider.dart';
import '../services/character_timeline_service.dart';
import 'character_timeline_screen.dart';
import 'custom_statuses_screen.dart';
import 'widgets/character_affiliations_editor.dart';
import 'widgets/character_alias_editor.dart';
import 'widgets/character_description_card.dart';
import 'widgets/character_relationships_editor.dart';
import 'widgets/character_status_editor.dart';
import 'widgets/character_status_indicator.dart';

class CharactersScreen extends ConsumerWidget {
  const CharactersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chars = ref.watch(charactersProvider);
    final hiddenAsync = ref.watch(hiddenCharacterIdsForReaderProvider);
    final reveal = ref.watch(revealHiddenCharactersProvider);
    final l = AppLocalizations.of(context);
    return Scaffold(
      drawer: const MainDrawer(currentRoute: '/characters'),
      appBar: AppBar(
        title: Text(l.navCharacters),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Custom statuses',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CustomStatusesScreen(),
              ),
            ),
          ),
          const _SyncFirstAppearancesButton(),
          hiddenAsync.maybeWhen(
            data: (ids) {
              if (ids.isEmpty) return const SizedBox.shrink();
              return IconButton(
                tooltip: reveal
                    ? 'Hide unencountered characters'
                    : '${ids.length} hidden — reveal',
                icon: Icon(
                  reveal
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () => ref
                    .read(revealHiddenCharactersProvider.notifier)
                    .state = !reveal,
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: const _DeleteAffiliationFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: chars.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) return const _EmptyState();
          final hiddenIds = hiddenAsync.maybeWhen(
            data: (s) => s,
            orElse: () => const <int>{},
          );
          final visible = reveal
              ? list
              : list
                  .where((c) => c.id == null || !hiddenIds.contains(c.id))
                  .toList();
          if (visible.isEmpty) {
            return _AllHiddenState(hiddenCount: hiddenIds.length);
          }
          // Group by series. Globals (series == null) go last under
          // "Other" so the more-specific series buckets surface first.
          final bySeries = <String?, List<Character>>{};
          for (final c in visible) {
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
                      (series ?? l.libraryGroupOther).toUpperCase(),
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

/// Within one series group, renders a hierarchical affiliation tree
/// (using each affiliation's `parent_id`) and the characters that
/// belong to each affiliation. Long-press an affiliation header to
/// drag it; drop it on another header to nest underneath, or onto
/// the series-level "top-level" zone to detach. Hovering over a
/// row for ~500 ms auto-expands it so you can drop deeper.
class _SeriesAffiliations extends ConsumerStatefulWidget {
  const _SeriesAffiliations({
    required this.series,
    required this.characters,
  });

  final String? series;
  final List<Character> characters;

  @override
  ConsumerState<_SeriesAffiliations> createState() =>
      _SeriesAffiliationsState();
}

class _SeriesAffiliationsState
    extends ConsumerState<_SeriesAffiliations> {
  final Set<int> _expanded = <int>{};
  Timer? _hoverTimer;
  int? _hoverId;

  @override
  void dispose() {
    _hoverTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final affAll =
        ref.watch(affiliationsForSeriesProvider(widget.series));
    final affByChar =
        ref.watch(affiliationsByCharacterForSeriesProvider(widget.series));
    return affAll.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text('Error: $e'),
      data: (allAffs) {
        return affByChar.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          ),
          error: (e, _) => Text('Error: $e'),
          data: (byChar) {
            // Group characters under each affiliation they have. A
            // character with multiple affiliations appears under each.
            // Empty-affiliation characters go in "Unaffiliated".
            final charsByAff = <int, List<Character>>{};
            final unaffiliated = <Character>[];
            for (final c in widget.characters) {
              final ams = byChar[c.id] ?? const <Affiliation>[];
              if (ams.isEmpty) {
                unaffiliated.add(c);
                continue;
              }
              for (final a in ams) {
                (charsByAff[a.id!] ??= []).add(c);
              }
            }
            // Build {parentId → list of children} so we can render
            // the tree recursively.
            final byParent = <int?, List<Affiliation>>{};
            for (final a in allAffs) {
              (byParent[a.parentId] ??= []).add(a);
            }
            for (final list in byParent.values) {
              list.sort(
                (a, b) =>
                    a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SeriesDropZone(
                  onAccept: (a) => _reparent(a, null, allAffs),
                ),
                ..._buildAffLevel(
                  byParent: byParent,
                  charsByAff: charsByAff,
                  parentId: null,
                  depth: 0,
                  allAffs: allAffs,
                ),
                if (unaffiliated.isNotEmpty)
                  Theme(
                    data: theme.copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: false,
                      tilePadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      childrenPadding: EdgeInsets.zero,
                      title: Text(
                        AppLocalizations.of(context).charactersUnaffiliated,
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
      },
    );
  }

  List<Widget> _buildAffLevel({
    required Map<int?, List<Affiliation>> byParent,
    required Map<int, List<Character>> charsByAff,
    required int? parentId,
    required int depth,
    required List<Affiliation> allAffs,
  }) {
    final children = byParent[parentId] ?? const [];
    final out = <Widget>[];
    for (final aff in children) {
      final hasGrandchildren = (byParent[aff.id] ?? const []).isNotEmpty;
      final hasOwnChars = (charsByAff[aff.id] ?? const []).isNotEmpty;
      final isExpanded = _expanded.contains(aff.id);
      final isHovered = _hoverId == aff.id;

      out.add(_AffiliationTreeRow(
        affiliation: aff,
        depth: depth,
        isExpanded: isExpanded,
        isHovered: isHovered,
        hasChildren: hasGrandchildren || hasOwnChars,
        onToggle: (hasGrandchildren || hasOwnChars)
            ? () => setState(() {
                  if (isExpanded) {
                    _expanded.remove(aff.id);
                  } else {
                    _expanded.add(aff.id!);
                  }
                })
            : null,
        onWillAccept: (incoming) {
          if (incoming == null || incoming.id == aff.id) return false;
          if (_isDescendantOf(aff, incoming, allAffs)) return false;
          _hoverTimer?.cancel();
          setState(() => _hoverId = aff.id);
          _hoverTimer = Timer(const Duration(milliseconds: 500), () {
            if (!mounted) return;
            if ((hasGrandchildren || hasOwnChars) && !isExpanded) {
              setState(() {
                _expanded.add(aff.id!);
                _hoverId = null;
              });
            }
          });
          return true;
        },
        onLeave: (_) {
          _hoverTimer?.cancel();
          if (_hoverId == aff.id) {
            setState(() => _hoverId = null);
          }
        },
        onAccept: (dragged) => _reparent(dragged, aff.id, allAffs),
      ));

      if (isExpanded) {
        // Nested affiliations come first so the user sees the whole
        // sub-tree of factions before the characters that belong
        // directly to this faction. Drop targets stay in place.
        out.addAll(_buildAffLevel(
          byParent: byParent,
          charsByAff: charsByAff,
          parentId: aff.id,
          depth: depth + 1,
          allAffs: allAffs,
        ));
        final ownChars = charsByAff[aff.id] ?? const <Character>[];
        for (final c in ownChars) {
          out.add(_CharacterCard(
            character: c,
            collapsedIndent: 16.0 + (depth + 1) * 14,
          ));
          out.add(const SizedBox(height: 10));
        }
      }
    }
    return out;
  }

  bool _isDescendantOf(
    Affiliation candidate,
    Affiliation root,
    List<Affiliation> all,
  ) {
    var cur = candidate;
    final byId = {for (final a in all) a.id: a};
    var depth = 0;
    while (cur.parentId != null && depth < 100) {
      if (cur.parentId == root.id) return true;
      final parent = byId[cur.parentId];
      if (parent == null) return false;
      cur = parent;
      depth++;
    }
    return false;
  }

  Future<void> _reparent(
    Affiliation dragged,
    int? newParentId,
    List<Affiliation> allAffs,
  ) async {
    if (dragged.id == null) return;
    if (dragged.parentId == newParentId) return;
    if (newParentId != null) {
      final byId = {for (final a in allAffs) a.id: a};
      final newParent = byId[newParentId];
      if (newParent != null && _isDescendantOf(newParent, dragged, allAffs)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot nest a parent under its child.'),
          ),
        );
        return;
      }
    }
    await ref.read(characterRepositoryProvider).setAffiliationParent(
          affiliationId: dragged.id!,
          parentId: newParentId,
        );
    ref.read(characterRevisionProvider.notifier).state++;
  }
}

class _SeriesDropZone extends StatelessWidget {
  const _SeriesDropZone({required this.onAccept});
  final void Function(Affiliation) onAccept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DragTarget<Affiliation>(
      onWillAcceptWithDetails: (d) => d.data.parentId != null,
      onAcceptWithDetails: (d) => onAccept(d.data),
      builder: (_, hovering, __) {
        if (hovering.isEmpty) return const SizedBox(height: 4);
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.primary),
          ),
          child: Row(
            children: [
              Icon(
                Icons.vertical_align_top,
                size: 18,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Text(
                'Drop here to make top-level',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AffiliationTreeRow extends StatelessWidget {
  const _AffiliationTreeRow({
    required this.affiliation,
    required this.depth,
    required this.isExpanded,
    required this.isHovered,
    required this.hasChildren,
    required this.onToggle,
    required this.onWillAccept,
    required this.onLeave,
    required this.onAccept,
  });

  final Affiliation affiliation;
  final int depth;
  final bool isExpanded;
  final bool isHovered;
  final bool hasChildren;
  final VoidCallback? onToggle;
  final bool Function(Affiliation?) onWillAccept;
  final void Function(Affiliation?) onLeave;
  final void Function(Affiliation) onAccept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DragTarget<Affiliation>(
      onWillAcceptWithDetails: (d) => onWillAccept(d.data),
      onLeave: onLeave,
      onAcceptWithDetails: (d) => onAccept(d.data),
      builder: (_, hovering, __) {
        final hot = hovering.isNotEmpty || isHovered;
        return LongPressDraggable<Affiliation>(
          data: affiliation,
          delay: const Duration(milliseconds: 250),
          feedback: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x44000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                affiliation.name,
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.4,
            child: _row(theme, hot),
          ),
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(6),
            child: _row(theme, hot),
          ),
        );
      },
    );
  }

  Widget _row(ThemeData theme, bool hot) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: EdgeInsets.only(left: 12.0 + depth * 18),
      decoration: BoxDecoration(
        color: hot
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
            : null,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: hot ? theme.colorScheme.primary : Colors.transparent,
          width: 1.4,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasChildren
                ? (isExpanded ? Icons.expand_more : Icons.chevron_right)
                : Icons.circle,
            size: hasChildren ? 22 : 6,
            color: hasChildren
                ? theme.colorScheme.onSurface
                : theme.colorScheme.outline,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                affiliation.name,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Icon(
            Icons.drag_handle,
            size: 16,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _CharacterCard extends ConsumerStatefulWidget {
  const _CharacterCard({
    required this.character,
    this.collapsedIndent = 0,
  });

  final Character character;

  /// Left margin applied while the card is collapsed. When the user
  /// expands the card we drop the indent so the inner widgets get the
  /// full screen width — deep affiliation nesting otherwise squeezes
  /// the editor against the right edge.
  final double collapsedIndent;

  @override
  ConsumerState<_CharacterCard> createState() => _CharacterCardState();
}

class _CharacterCardState extends ConsumerState<_CharacterCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final character = widget.character;
    final theme = Theme.of(context);
    final descs =
        ref.watch(descriptionsForCharacterProvider(character.id!));
    final aliases = ref.watch(aliasesForCharacterProvider(character.id!));
    final displayAsync =
        ref.watch(statusDisplayForCharacterProvider(character.id!));
    final display = displayAsync.maybeWhen(
      data: (d) => d,
      orElse: () => StatusDisplay(
        label: builtInStatusLabel(character.status),
        color: builtInStatusColor(character.status),
        builtIn: character.status,
      ),
    );
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(left: _expanded ? 0 : widget.collapsedIndent),
      child: Card(
        child: ExpansionTile(
          onExpansionChanged: (open) => setState(() => _expanded = open),
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
            CharacterStatusDot(
              color: display.color,
              label: display.label,
              size: 10,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                character.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.timeline),
              tooltip: AppLocalizations.of(context).charactersTimelineTooltip,
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
              tooltip: AppLocalizations.of(context).charactersDeleteTooltip,
              onPressed: () => _confirmDelete(context, ref),
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          CharacterStatusEditor(character: character),
          const Divider(),
          CharacterAliasEditor(character: character),
          const SizedBox(height: 12),
          CharacterAffiliationsEditor(character: character),
          const SizedBox(height: 16),
          CharacterRelationshipsEditor(character: character),
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
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final character = widget.character;
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(l.charactersDeleteTitle(character.name)),
        content: Text(l.charactersDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: Text(l.actionDelete),
          ),
        ],
      ),
    );
    if (ok != true || character.id == null) return;
    await ref.read(charactersProvider.notifier).remove(character.id!);
    ref.read(characterRevisionProvider.notifier).state++;
  }
}

/// App-bar action that runs the first-appearance auto-detector across
/// every character at once. Iterates per-character so progress is
/// linear; while running, the button swaps to a tiny spinner and
/// disables further taps.
class _SyncFirstAppearancesButton extends ConsumerStatefulWidget {
  const _SyncFirstAppearancesButton();

  @override
  ConsumerState<_SyncFirstAppearancesButton> createState() =>
      _SyncFirstAppearancesButtonState();
}

class _SyncFirstAppearancesButtonState
    extends ConsumerState<_SyncFirstAppearancesButton> {
  bool _running = false;
  int _done = 0;
  int _total = 0;

  Future<void> _run() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Sync first appearances?'),
        content: const Text(
          'Scans every EPUB in your library to set each character\'s '
          'first-seen marker to the earliest chapter where their '
          'name or alias appears. Existing values are overwritten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Run'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _running = true;
      _done = 0;
      _total = 0;
    });
    final repo = ref.read(characterRepositoryProvider);
    final svc = CharacterTimelineService(repo);
    final all = await repo.listAll();
    final allBooks = await ref.read(bookRepositoryProvider).getAll();
    setState(() => _total = all.length);
    var updated = 0;
    var skipped = 0;
    for (final c in all) {
      if (c.id == null) {
        if (mounted) setState(() => _done++);
        continue;
      }
      final scoped = _booksFor(allBooks, c.series);
      try {
        final hit = await svc.findFirstAppearance(
          characterId: c.id!,
          books: scoped,
        );
        if (hit != null) {
          await repo.setFirstSeen(
            characterId: c.id!,
            bookId: hit.book.id,
            chapterIndex: hit.chapterIndex,
          );
          updated++;
        } else {
          skipped++;
        }
      } catch (_) {
        skipped++;
      }
      if (mounted) setState(() => _done++);
    }
    ref.read(characterRevisionProvider.notifier).state++;
    if (!mounted) return;
    setState(() => _running = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Synced — $updated updated, $skipped unchanged',
        ),
      ),
    );
  }

  List<Book> _booksFor(List<Book> all, String? series) {
    final filtered = all
        .where((b) =>
            b.format == BookFormat.epub &&
            (series == null ||
                (b.series != null &&
                    b.series!.toLowerCase() == series.toLowerCase())))
        .toList();
    filtered.sort((a, b) {
      final an = a.seriesNumber;
      final bn = b.seriesNumber;
      if (an != null && bn != null) return an.compareTo(bn);
      if (an != null) return -1;
      if (bn != null) return 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    if (_running) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              _total == 0 ? '…' : '$_done / $_total',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      );
    }
    return IconButton(
      icon: const Icon(Icons.travel_explore),
      tooltip: 'Sync first appearances',
      onPressed: _run,
    );
  }
}

class _AllHiddenState extends ConsumerWidget {
  const _AllHiddenState({required this.hiddenCount});
  final int hiddenCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.visibility_off_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No characters at your reading position',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$hiddenCount character${hiddenCount == 1 ? '' : 's'} '
              "haven't appeared yet in the part of the book "
              "you've read.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Reveal anyway'),
              onPressed: () => ref
                  .read(revealHiddenCharactersProvider.notifier)
                  .state = true,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
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
            Text(l.charactersEmptyTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              l.charactersEmptyHint,
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

/// Bottom-center red trash button for deleting affiliations. Two paths:
///   * Tap → bottom sheet listing every affiliation with a delete row
///   * Drag an affiliation row from the tree on top → drop confirms
/// Both go through [_confirmAndDelete] for the actual deletion so the
/// confirmation dialog wording stays consistent.
class _DeleteAffiliationFab extends ConsumerStatefulWidget {
  const _DeleteAffiliationFab();

  @override
  ConsumerState<_DeleteAffiliationFab> createState() =>
      _DeleteAffiliationFabState();
}

class _DeleteAffiliationFabState extends ConsumerState<_DeleteAffiliationFab> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DragTarget<Affiliation>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => _confirmAndDelete(d.data),
      builder: (_, hovering, __) {
        final hot = hovering.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: hot
              ? const EdgeInsets.symmetric(horizontal: 28, vertical: 14)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.error,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.error.withValues(alpha: 0.4),
                blurRadius: hot ? 14 : 6,
                offset: const Offset(0, 2),
              ),
            ],
            border: hot
                ? Border.all(
                    color: theme.colorScheme.onError.withValues(alpha: 0.6),
                    width: 2,
                  )
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showPicker,
              borderRadius: BorderRadius.circular(28),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.onError,
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      child: hot
                          ? Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                'Drop to delete',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.onError,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPicker() async {
    final repo = ref.read(characterRepositoryProvider);
    final all = await repo.listAllAffiliations();
    if (!mounted) return;
    if (all.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No affiliations to delete.')),
      );
      return;
    }
    final picked = await showModalBottomSheet<Affiliation>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        final maxH = MediaQuery.of(sheetCtx).size.height * 0.7;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    'Delete affiliation',
                    style: Theme.of(sheetCtx).textTheme.titleLarge,
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: all.length,
                    itemBuilder: (_, i) {
                      final a = all[i];
                      return ListTile(
                        leading: Icon(
                          Icons.group_outlined,
                          color: Theme.of(sheetCtx).colorScheme.primary,
                        ),
                        title: Text(a.name),
                        subtitle: a.series != null
                            ? Text(a.series!)
                            : const Text('Global'),
                        trailing: const Icon(Icons.delete_outline),
                        onTap: () => Navigator.pop(sheetCtx, a),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null) await _confirmAndDelete(picked);
  }

  Future<void> _confirmAndDelete(Affiliation a) async {
    if (a.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Delete "${a.name}"?'),
        content: const Text(
          'Characters lose their membership. Sub-affiliations become '
          'top-level. The affiliation itself is removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(characterRepositoryProvider).deleteAffiliation(a.id!);
    ref.read(characterRevisionProvider.notifier).state++;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted "${a.name}"')),
    );
  }
}
