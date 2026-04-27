import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/character.dart';
import '../../providers/character_provider.dart';

/// Reusable "Also known as" row showing every alias as a chip with a
/// remove button, plus an inline "+ Add alias" affordance. Used both in
/// the descriptions bottom sheet (in-reader) and in the Characters
/// management screen.
class CharacterAliasEditor extends ConsumerStatefulWidget {
  const CharacterAliasEditor({super.key, required this.character});

  final Character character;

  @override
  ConsumerState<CharacterAliasEditor> createState() =>
      _CharacterAliasEditorState();
}

class _CharacterAliasEditorState
    extends ConsumerState<CharacterAliasEditor> {
  bool _adding = false;
  TextEditingController? _ctrl;

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _startAdd() {
    final c = _ctrl ??= TextEditingController();
    c.text = '';
    setState(() => _adding = true);
  }

  void _cancelAdd() => setState(() => _adding = false);

  Future<void> _commitAdd() async {
    final value = _ctrl?.text.trim() ?? '';
    if (value.isEmpty || widget.character.id == null) {
      _cancelAdd();
      return;
    }
    await ref.read(characterRepositoryProvider).addAlias(
          characterId: widget.character.id!,
          alias: value,
        );
    if (!mounted) return;
    setState(() => _adding = false);
    ref.read(characterRevisionProvider.notifier).state++;
  }

  Future<void> _delete(String alias) async {
    if (widget.character.id == null) return;
    await ref.read(characterRepositoryProvider).deleteAlias(
          characterId: widget.character.id!,
          alias: alias,
        );
    if (!mounted) return;
    ref.read(characterRevisionProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final aliases =
        ref.watch(aliasesForCharacterProvider(widget.character.id!));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Also known as',
          style: theme.textTheme.labelMedium?.copyWith(
            color: muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        aliases.when(
          loading: () => const SizedBox(
            height: 32,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (e, _) => Text('Aliases error: $e'),
          data: (list) => Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final alias in list)
                InputChip(
                  label: Text(alias),
                  onDeleted: () => _delete(alias),
                  deleteIconColor:
                      theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              if (_adding)
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _ctrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'New alias',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check, size: 18),
                        onPressed: _commitAdd,
                      ),
                    ),
                    onSubmitted: (_) => _commitAdd(),
                  ),
                )
              else
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text('Add alias'),
                  onPressed: _startAdd,
                ),
              if (_adding)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: _cancelAdd,
                  tooltip: 'Cancel',
                ),
            ],
          ),
        ),
      ],
    );
  }
}
