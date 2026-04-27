import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/character_description.dart';
import '../../providers/character_provider.dart';

/// Reusable card for a single character description with inline
/// edit/delete. Used both in the in-reader descriptions sheet and in
/// the Characters management screen.
class CharacterDescriptionCard extends ConsumerStatefulWidget {
  const CharacterDescriptionCard({
    super.key,
    required this.description,
  });

  final CharacterDescription description;

  @override
  ConsumerState<CharacterDescriptionCard> createState() =>
      _CharacterDescriptionCardState();
}

class _CharacterDescriptionCardState
    extends ConsumerState<CharacterDescriptionCard> {
  bool _editing = false;
  TextEditingController? _ctrl;

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _startEdit() {
    final c = _ctrl ??= TextEditingController();
    c.text = widget.description.text;
    setState(() => _editing = true);
  }

  void _cancelEdit() => setState(() => _editing = false);

  Future<void> _save() async {
    final text = _ctrl?.text.trim() ?? '';
    final id = widget.description.id;
    if (text.isEmpty || id == null) return;
    await ref.read(characterRepositoryProvider).updateDescription(
          id: id,
          text: text,
        );
    if (!mounted) return;
    setState(() => _editing = false);
    ref.read(characterRevisionProvider.notifier).state++;
  }

  Future<void> _delete() async {
    final id = widget.description.id;
    if (id == null) return;
    await ref.read(characterRepositoryProvider).deleteDescription(id);
    if (!mounted) return;
    ref.read(characterRevisionProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Spacer(),
                if (_editing) ...[
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Cancel',
                    onPressed: _cancelEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.check, size: 20),
                    tooltip: 'Save',
                    onPressed: _save,
                  ),
                ] else ...[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Edit',
                    onPressed: _startEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: 'Delete',
                    onPressed: _delete,
                  ),
                ],
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 8, 4),
              child: _editing
                  ? TextField(
                      controller: _ctrl,
                      maxLines: null,
                      minLines: 3,
                      autofocus: true,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    )
                  : Text(
                      widget.description.text,
                      style:
                          theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
              child: Text(
                _fmtDate(widget.description.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
