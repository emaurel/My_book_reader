import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/character.dart';
import '../../providers/character_provider.dart';

/// Bottom sheet for attaching the selected text as a description of a
/// character. The user picks an existing character (or creates one
/// inline) and the [text] is saved as that character's latest
/// description. When [bookSeries] is provided the create flow offers an
/// option to scope the new character to that series.
Future<bool?> showAddCharacterDescriptionSheet(
  BuildContext context, {
  required String text,
  int? bookId,
  String? bookSeries,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetCtx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom,
      ),
      child: _AddCharacterDescriptionSheet(
        text: text,
        bookId: bookId,
        bookSeries: bookSeries,
      ),
    ),
  );
}

class _AddCharacterDescriptionSheet extends ConsumerStatefulWidget {
  const _AddCharacterDescriptionSheet({
    required this.text,
    this.bookId,
    this.bookSeries,
  });
  final String text;
  final int? bookId;
  final String? bookSeries;

  @override
  ConsumerState<_AddCharacterDescriptionSheet> createState() =>
      _AddCharacterDescriptionSheetState();
}

class _AddCharacterDescriptionSheetState
    extends ConsumerState<_AddCharacterDescriptionSheet> {
  static const _newCharacterId = -1;
  int? _selectedCharacterId;
  final _newNameCtrl = TextEditingController();
  bool _saving = false;
  bool _scopeToSeries = true; // default true since characters usually are per-series

  @override
  void dispose() {
    _newNameCtrl.dispose();
    super.dispose();
  }

  bool get _canScope =>
      widget.bookSeries != null && widget.bookSeries!.isNotEmpty;

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = ref.read(characterRepositoryProvider);

    int characterId;
    if (_selectedCharacterId == _newCharacterId ||
        _selectedCharacterId == null) {
      final name = _newNameCtrl.text.trim();
      if (name.isEmpty) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter the character\'s name.')),
        );
        return;
      }
      // Reuse if we already have a character with this name in scope.
      final scope = (_canScope && _scopeToSeries) ? widget.bookSeries : null;
      final existing = await repo.findByName(name, series: scope);
      if (existing != null) {
        characterId = existing.id!;
      } else {
        try {
          characterId = await ref
              .read(charactersProvider.notifier)
              .create(name: name, series: scope);
        } catch (e) {
          setState(() => _saving = false);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not create character: $e')),
          );
          return;
        }
      }
    } else {
      characterId = _selectedCharacterId!;
    }

    await repo.addDescription(
      characterId: characterId,
      text: widget.text,
      bookId: widget.bookId,
    );
    ref.read(characterRevisionProvider.notifier).state++;

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final candidates =
        ref.watch(charactersForSeriesProvider(widget.bookSeries));

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add to character',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 20),
            candidates.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Error loading characters: $e'),
              data: (list) => _buildPicker(context, list),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _saving ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPicker(BuildContext context, List<Character> list) {
    if (_selectedCharacterId == null) {
      _selectedCharacterId =
          list.isEmpty ? _newCharacterId : list.first.id;
    }
    final isCreating = _selectedCharacterId == _newCharacterId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int>(
          initialValue: _selectedCharacterId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Character',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final c in list)
              DropdownMenuItem(
                value: c.id,
                child: _CharacterRow(character: c),
              ),
            const DropdownMenuItem(
              value: _newCharacterId,
              child: Row(
                children: [
                  Icon(Icons.add, size: 18),
                  SizedBox(width: 6),
                  Text('Create new character'),
                ],
              ),
            ),
          ],
          onChanged: (v) => setState(() => _selectedCharacterId = v),
        ),
        if (isCreating) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _newNameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Character name',
              border: OutlineInputBorder(),
            ),
          ),
          if (_canScope) ...[
            const SizedBox(height: 8),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _scopeToSeries,
              onChanged: (v) =>
                  setState(() => _scopeToSeries = v ?? false),
              title: Text(
                'Only show in "${widget.bookSeries}" books',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: const Text(
                'When off, the character is recognized everywhere.',
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _CharacterRow extends StatelessWidget {
  const _CharacterRow({required this.character});
  final Character character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(character.name, overflow: TextOverflow.ellipsis),
        ),
        if (character.series != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              character.series!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
