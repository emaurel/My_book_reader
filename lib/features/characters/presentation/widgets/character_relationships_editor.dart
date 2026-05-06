import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/character.dart';
import '../../domain/character_relationship.dart';
import '../../providers/character_provider.dart';

/// Lists every relationship the character is part of, with an "Add"
/// button that opens a target+kind+note picker. Each relationship can
/// be deleted via long-press; the spoiler-anchor chip is shown
/// inline so users can tell at a glance which entries are gated.
class CharacterRelationshipsEditor extends ConsumerWidget {
  const CharacterRelationshipsEditor({super.key, required this.character});

  final Character character;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (character.id == null) return const SizedBox.shrink();
    final asyncRels = ref.watch(relationshipsForCharacterProvider(character.id!));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Relationships',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              onPressed: () => _addRelationship(context, ref),
            ),
          ],
        ),
        asyncRels.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
          error: (e, _) => Text('Error: $e'),
          data: (list) {
            if (list.isEmpty) {
              return Text(
                'No relationships yet.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in list)
                  _RelationshipRow(
                    key: ValueKey(r.id),
                    relationship: r,
                    onDelete: () async {
                      if (r.id == null) return;
                      await ref
                          .read(characterRepositoryProvider)
                          .deleteRelationship(r.id!);
                      ref.read(characterRevisionProvider.notifier).state++;
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _addRelationship(BuildContext context, WidgetRef ref) async {
    final candidates = await ref
        .read(characterRepositoryProvider)
        .listForSeries(character.series);
    final pool = candidates.where((c) => c.id != character.id).toList();
    if (pool.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No other characters in this series — create one first.',
          ),
        ),
      );
      return;
    }
    if (!context.mounted) return;
    final result = await showModalBottomSheet<_RelationshipDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom,
        ),
        child: _AddRelationshipSheet(others: pool),
      ),
    );
    if (result == null || character.id == null) return;
    await ref.read(characterRepositoryProvider).addRelationship(
          fromCharacterId: character.id!,
          toCharacterId: result.targetId,
          kind: result.kind,
          note: result.note,
          spoilerChapterIndex: result.spoilerChapter,
        );
    ref.read(characterRevisionProvider.notifier).state++;
  }
}

class _RelationshipDraft {
  _RelationshipDraft({
    required this.targetId,
    required this.kind,
    this.note,
    this.spoilerChapter,
  });
  final int targetId;
  final RelationshipKind kind;
  final String? note;
  final int? spoilerChapter;
}

class _AddRelationshipSheet extends ConsumerStatefulWidget {
  const _AddRelationshipSheet({required this.others});
  final List<Character> others;

  @override
  ConsumerState<_AddRelationshipSheet> createState() =>
      _AddRelationshipSheetState();
}

class _AddRelationshipSheetState
    extends ConsumerState<_AddRelationshipSheet> {
  int? _targetId;
  RelationshipKind _kind = RelationshipKind.friend;
  final _noteCtrl = TextEditingController();
  final _chapterCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    _chapterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    _targetId ??= widget.others.first.id;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add relationship',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _targetId,
              decoration: const InputDecoration(
                labelText: 'Other character',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final c in widget.others)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _targetId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RelationshipKind>(
              initialValue: _kind,
              decoration: const InputDecoration(
                labelText: 'Relationship',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final k in RelationshipKind.values)
                  DropdownMenuItem(
                    value: k,
                    child: Text(_kindLabel(k)),
                  ),
              ],
              onChanged: (v) => setState(() => _kind = v ?? RelationshipKind.other),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _chapterCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Spoiler chapter (1-indexed, optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _targetId == null
                      ? null
                      : () {
                          final ch = int.tryParse(_chapterCtrl.text.trim());
                          Navigator.pop(
                            context,
                            _RelationshipDraft(
                              targetId: _targetId!,
                              kind: _kind,
                              note: _noteCtrl.text.trim().isEmpty
                                  ? null
                                  : _noteCtrl.text.trim(),
                              spoilerChapter:
                                  ch != null && ch > 0 ? ch - 1 : null,
                            ),
                          );
                        },
                  child: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RelationshipRow extends ConsumerWidget {
  const _RelationshipRow({
    super.key,
    required this.relationship,
    required this.onDelete,
  });

  final CharacterRelationship relationship;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncOther =
        ref.watch(characterByIdProvider(relationship.toCharacterId));
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: asyncOther.when(
        loading: () => const Text('…'),
        error: (e, _) => Text('Error: $e'),
        data: (other) => Text(
          '${_kindLabel(relationship.kind)} — ${other?.name ?? '?'}',
        ),
      ),
      subtitle: relationship.note == null && relationship.spoilerChapterIndex == null
          ? null
          : Text.rich(
              TextSpan(children: [
                if (relationship.note != null)
                  TextSpan(text: relationship.note),
                if (relationship.spoilerChapterIndex != null)
                  TextSpan(
                    text:
                        '${relationship.note != null ? '  ·  ' : ''}'
                        'Ch ${relationship.spoilerChapterIndex! + 1}+',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ]),
            ),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 18),
        onPressed: onDelete,
      ),
    );
  }
}

String _kindLabel(RelationshipKind k) {
  switch (k) {
    case RelationshipKind.parent:
      return 'Parent of';
    case RelationshipKind.child:
      return 'Child of';
    case RelationshipKind.sibling:
      return 'Sibling of';
    case RelationshipKind.spouse:
      return 'Spouse of';
    case RelationshipKind.partner:
      return 'Partner of';
    case RelationshipKind.friend:
      return 'Friend of';
    case RelationshipKind.rival:
      return 'Rival of';
    case RelationshipKind.enemy:
      return 'Enemy of';
    case RelationshipKind.mentor:
      return 'Mentor of';
    case RelationshipKind.student:
      return 'Student of';
    case RelationshipKind.ally:
      return 'Ally of';
    case RelationshipKind.other:
      return 'Linked to';
  }
}
