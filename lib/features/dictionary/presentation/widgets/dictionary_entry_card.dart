import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dictionary_entry.dart';
import '../../providers/dictionary_provider.dart';

/// Reusable card for a single dictionary entry with inline edit /
/// delete. The [header] is the small accent line above the definition
/// — typically the dictionary name (when listing all entries for a
/// word) or the word itself (when listing a dictionary's entries).
class DictionaryEntryCard extends ConsumerStatefulWidget {
  const DictionaryEntryCard({
    super.key,
    required this.header,
    required this.entry,
  });

  final String header;
  final DictionaryEntry entry;

  @override
  ConsumerState<DictionaryEntryCard> createState() =>
      _DictionaryEntryCardState();
}

class _DictionaryEntryCardState extends ConsumerState<DictionaryEntryCard> {
  bool _editing = false;
  TextEditingController? _ctrl;

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _startEdit() {
    final c = _ctrl ??= TextEditingController();
    c.text = widget.entry.definition;
    setState(() => _editing = true);
  }

  void _cancelEdit() => setState(() => _editing = false);

  Future<void> _save() async {
    final text = _ctrl?.text.trim() ?? '';
    final id = widget.entry.id;
    if (text.isEmpty || id == null) return;
    await ref.read(dictionaryRepositoryProvider).updateEntry(
          id: id,
          definition: text,
        );
    if (!mounted) return;
    setState(() => _editing = false);
    ref.read(dictionaryEntriesRevisionProvider.notifier).state++;
  }

  Future<void> _delete() async {
    final id = widget.entry.id;
    if (id == null) return;
    await ref.read(dictionaryRepositoryProvider).deleteEntry(id);
    if (!mounted) return;
    ref.read(dictionaryEntriesRevisionProvider.notifier).state++;
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
                Expanded(
                  child: Text(
                    widget.header,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
              padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
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
                      widget.entry.definition,
                      style:
                          theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
              child: Text(
                _fmtDate(widget.entry.createdAt),
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
