import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/character.dart';
import '../../providers/character_provider.dart';
import 'character_status_indicator.dart';

/// Editable status row for a character. Shows the current status
/// (with colored dot) plus an "Edit" button that pops a sheet for
/// changing the status and its spoiler anchor.
class CharacterStatusEditor extends ConsumerWidget {
  const CharacterStatusEditor({super.key, required this.character});

  final Character character;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          'Status',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 12),
        CharacterStatusDot(status: character.status, size: 12),
        const SizedBox(width: 6),
        Text(_labelFor(character.status)),
        const Spacer(),
        TextButton.icon(
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit'),
          onPressed: () => _showEditor(context, ref),
        ),
      ],
    );
  }

  String _labelFor(CharacterStatus? s) {
    if (s == null) return '—';
    switch (s) {
      case CharacterStatus.alive:
        return 'Alive';
      case CharacterStatus.dead:
        return 'Dead';
      case CharacterStatus.missing:
        return 'Missing';
      case CharacterStatus.unknown:
        return 'Unknown';
    }
  }

  Future<void> _showEditor(BuildContext context, WidgetRef ref) async {
    final picked = await showModalBottomSheet<_StatusEdit>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _StatusEditSheet(
        initial: _StatusEdit(
          status: character.status,
          spoilerBookId: character.statusSpoilerBookId,
          spoilerChapterIndex: character.statusSpoilerChapterIndex,
        ),
      ),
    );
    if (picked == null || character.id == null) return;
    await ref.read(characterRepositoryProvider).setStatus(
          characterId: character.id!,
          status: picked.status,
          spoilerBookId: picked.spoilerBookId,
          spoilerChapterIndex: picked.spoilerChapterIndex,
        );
    ref.read(characterRevisionProvider.notifier).state++;
  }
}

class _StatusEdit {
  _StatusEdit({this.status, this.spoilerBookId, this.spoilerChapterIndex});
  CharacterStatus? status;
  int? spoilerBookId;
  int? spoilerChapterIndex;
}

class _StatusEditSheet extends StatefulWidget {
  const _StatusEditSheet({required this.initial});
  final _StatusEdit initial;

  @override
  State<_StatusEditSheet> createState() => _StatusEditSheetState();
}

class _StatusEditSheetState extends State<_StatusEditSheet> {
  late CharacterStatus? _status;
  late final TextEditingController _chapterCtrl;

  @override
  void initState() {
    super.initState();
    _status = widget.initial.status;
    _chapterCtrl = TextEditingController(
      text: widget.initial.spoilerChapterIndex != null
          ? (widget.initial.spoilerChapterIndex! + 1).toString()
          : '',
    );
  }

  @override
  void dispose() {
    _chapterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _chip(null, 'Not set'),
                _chip(CharacterStatus.alive, 'Alive'),
                _chip(CharacterStatus.dead, 'Dead'),
                _chip(CharacterStatus.missing, 'Missing'),
                _chip(CharacterStatus.unknown, 'Unknown'),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Spoiler anchor',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Optional — readers in the same book at an earlier '
              'chapter will see "—" instead of this status.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _chapterCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Chapter (1-indexed)',
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
                  onPressed: () {
                    final raw = _chapterCtrl.text.trim();
                    final parsed = int.tryParse(raw);
                    Navigator.pop(
                      context,
                      _StatusEdit(
                        status: _status,
                        spoilerBookId: widget.initial.spoilerBookId,
                        spoilerChapterIndex:
                            parsed != null && parsed > 0 ? parsed - 1 : null,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(CharacterStatus? s, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _status == s,
      onSelected: (_) => setState(() => _status = s),
    );
  }
}
