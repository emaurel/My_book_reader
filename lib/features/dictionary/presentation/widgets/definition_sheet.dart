import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/dictionary_provider.dart';

/// Bottom sheet that shows all definitions for [word]. Each definition
/// is one entry; can have multiple if the same word lives in several
/// dictionaries. When [bookSeries] is provided, only entries from
/// global dictionaries OR ones scoped to that series are shown.
Future<void> showDefinitionSheet(
  BuildContext context, {
  required String word,
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
      child: _DefinitionSheet(word: word, bookSeries: bookSeries),
    ),
  );
}

class _DefinitionSheet extends ConsumerWidget {
  const _DefinitionSheet({required this.word, this.bookSeries});
  final String word;
  final String? bookSeries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final entries = ref.watch(
      entriesForWordProvider((word: word, series: bookSeries)),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              word,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            entries.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Error: $e'),
              data: (list) {
                if (list.isEmpty) {
                  return Text(
                    'No definition.',
                    style: theme.textTheme.bodyMedium,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final ewd in list)
                      _EntryCard(
                        key: ValueKey(ewd.entry.id),
                        ewd: ewd,
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
}

class _EntryCard extends ConsumerStatefulWidget {
  const _EntryCard({super.key, required this.ewd});

  final WordEntry ewd;

  @override
  ConsumerState<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends ConsumerState<_EntryCard> {
  bool _editing = false;
  // Controller is created lazily on first edit and kept alive for the
  // rest of the widget's lifetime — disposing it on cancel/save races
  // the rebuild and trips "TextEditingController used after disposed".
  TextEditingController? _ctrl;

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _startEdit() {
    final c = _ctrl ??= TextEditingController();
    c.text = widget.ewd.entry.definition;
    setState(() => _editing = true);
  }

  void _cancelEdit() {
    setState(() => _editing = false);
  }

  Future<void> _saveEdit() async {
    final text = _ctrl?.text.trim() ?? '';
    final id = widget.ewd.entry.id;
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
    final id = widget.ewd.entry.id;
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
                    widget.ewd.dictionaryName ?? '—',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
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
                    onPressed: _saveEdit,
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
                      widget.ewd.entry.definition,
                      style:
                          theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
              child: Text(
                _fmtDate(widget.ewd.entry.createdAt),
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
