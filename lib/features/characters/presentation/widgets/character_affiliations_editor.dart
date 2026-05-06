import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/affiliation.dart';
import '../../domain/character.dart';
import '../../providers/character_provider.dart';

/// Reusable "Affiliations" row showing every affiliation a character
/// belongs to as a chip with a remove button, plus an inline picker
/// that lets the user attach an existing affiliation or create a new
/// one. Mirrors the alias editor in shape.
class CharacterAffiliationsEditor extends ConsumerStatefulWidget {
  const CharacterAffiliationsEditor({super.key, required this.character});

  final Character character;

  @override
  ConsumerState<CharacterAffiliationsEditor> createState() =>
      _CharacterAffiliationsEditorState();
}

class _CharacterAffiliationsEditorState
    extends ConsumerState<CharacterAffiliationsEditor> {
  bool _adding = false;

  void _startAdd() => setState(() => _adding = true);
  void _cancelAdd() => setState(() => _adding = false);

  Future<void> _link(Affiliation affiliation) async {
    if (widget.character.id == null || affiliation.id == null) return;
    await ref.read(characterRepositoryProvider).linkAffiliation(
          characterId: widget.character.id!,
          affiliationId: affiliation.id!,
        );
    if (!mounted) return;
    setState(() => _adding = false);
    ref.read(characterRevisionProvider.notifier).state++;
  }

  Future<void> _unlink(Affiliation affiliation) async {
    if (widget.character.id == null || affiliation.id == null) return;
    await ref.read(characterRepositoryProvider).unlinkAffiliation(
          characterId: widget.character.id!,
          affiliationId: affiliation.id!,
        );
    if (!mounted) return;
    ref.read(characterRevisionProvider.notifier).state++;
  }

  Future<void> _createAndLink() async {
    final name = await _promptName(context);
    if (name == null || name.isEmpty) return;
    if (!mounted) return;
    final repo = ref.read(characterRepositoryProvider);
    final id = await repo.createAffiliation(
      name: name,
      series: widget.character.series,
    );
    int actualId = id;
    if (id == 0) {
      // Already existed; look it up to get the real id.
      final all = await repo
          .listAffiliationsForSeries(widget.character.series);
      final found = all.firstWhere(
        (a) => a.name.toLowerCase() == name.toLowerCase(),
        orElse: () => Affiliation(
          name: name,
          createdAt: DateTime.now(),
        ),
      );
      if (found.id == null) return;
      actualId = found.id!;
    }
    await _link(Affiliation(
      id: actualId,
      name: name,
      series: widget.character.series,
      createdAt: DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final mine =
        ref.watch(affiliationsForCharacterProvider(widget.character.id!));
    final available =
        ref.watch(affiliationsForSeriesProvider(widget.character.series));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Affiliations',
          style: theme.textTheme.labelMedium?.copyWith(
            color: muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        mine.when(
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
          error: (e, _) => Text('Affiliations error: $e'),
          data: (linked) => Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final a in linked)
                InputChip(
                  label: _AffiliationLabel(affiliation: a),
                  onDeleted: () => _unlink(a),
                  deleteIconColor:
                      theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              if (_adding)
                ..._addControls(linked, available)
              else
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text('Add affiliation'),
                  onPressed: _startAdd,
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Inline picker shown after Add: dropdown of existing affiliations
  /// not yet linked, plus a "+ New" chip. Cancel chip dismisses.
  List<Widget> _addControls(
    List<Affiliation> linked,
    AsyncValue<List<Affiliation>> available,
  ) {
    return available.when(
      loading: () => [const SizedBox.shrink()],
      error: (e, _) => [Text('Error: $e')],
      data: (all) {
        final linkedIds = {for (final a in linked) a.id};
        final candidates =
            all.where((a) => !linkedIds.contains(a.id)).toList();
        return [
          for (final a in candidates)
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: Text(a.name),
              onPressed: () => _link(a),
            ),
          ActionChip(
            avatar: const Icon(Icons.create, size: 16),
            label: const Text('New affiliation…'),
            onPressed: _createAndLink,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: _cancelAdd,
            tooltip: 'Cancel',
          ),
        ];
      },
    );
  }

  Future<String?> _promptName(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (_) => const _NewAffiliationDialog(),
    );
  }

}

class _AffiliationLabel extends ConsumerWidget {
  const _AffiliationLabel({required this.affiliation});
  final Affiliation affiliation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (affiliation.parentId == null) return Text(affiliation.name);
    final asyncAll =
        ref.watch(affiliationsForSeriesProvider(affiliation.series));
    return asyncAll.when(
      loading: () => Text(affiliation.name),
      error: (_, __) => Text(affiliation.name),
      data: (all) {
        final parent = all.firstWhere(
          (a) => a.id == affiliation.parentId,
          orElse: () => Affiliation(
            name: '?',
            createdAt: DateTime.now(),
          ),
        );
        return Text('${parent.name} → ${affiliation.name}');
      },
    );
  }
}

/// Stateful dialog for naming a new affiliation — owns its own
/// TextEditingController so disposing doesn't race the dialog close.
class _NewAffiliationDialog extends StatefulWidget {
  const _NewAffiliationDialog();

  @override
  State<_NewAffiliationDialog> createState() => _NewAffiliationDialogState();
}

class _NewAffiliationDialogState extends State<_NewAffiliationDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New affiliation'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Name'),
        onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_ctrl.text.trim()),
          child: const Text('Create'),
        ),
      ],
    );
  }
}
