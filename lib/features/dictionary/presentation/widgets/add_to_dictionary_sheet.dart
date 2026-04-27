import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dictionary.dart';
import '../../providers/dictionary_provider.dart';

/// Modal that lets the user pick (or create) a dictionary and add the
/// given [word] with a definition. When [bookSeries] is provided the
/// "create new" flow offers an option to scope the new dictionary to
/// that series so its entries only highlight in books from the same
/// series. Returns true on save, false/null on dismiss.
Future<bool?> showAddToDictionarySheet(
  BuildContext context, {
  required String word,
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
      child: _AddToDictionarySheet(word: word, bookSeries: bookSeries),
    ),
  );
}

class _AddToDictionarySheet extends ConsumerStatefulWidget {
  const _AddToDictionarySheet({required this.word, this.bookSeries});
  final String word;
  final String? bookSeries;

  @override
  ConsumerState<_AddToDictionarySheet> createState() =>
      _AddToDictionarySheetState();
}

class _AddToDictionarySheetState
    extends ConsumerState<_AddToDictionarySheet> {
  static const _newDictId = -1;
  int? _selectedDictId;
  final _newNameCtrl = TextEditingController();
  final _definitionCtrl = TextEditingController();
  bool _saving = false;
  bool _scopeToSeries = false;

  @override
  void dispose() {
    _newNameCtrl.dispose();
    _definitionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final definition = _definitionCtrl.text.trim();
    if (definition.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a definition.')),
      );
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(dictionaryRepositoryProvider);

    int dictId;
    if (_selectedDictId == _newDictId || _selectedDictId == null) {
      final name = _newNameCtrl.text.trim();
      if (name.isEmpty) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Give the new dictionary a name.')),
        );
        return;
      }
      try {
        dictId = await ref.read(dictionariesProvider.notifier).create(
              name: name,
              series:
                  (_scopeToSeries && widget.bookSeries != null)
                      ? widget.bookSeries
                      : null,
            );
      } catch (e) {
        setState(() => _saving = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create dictionary: $e')),
        );
        return;
      }
    } else {
      dictId = _selectedDictId!;
    }

    await repo.addEntry(
      dictionaryId: dictId,
      word: widget.word,
      definition: definition,
    );
    ref.read(dictionaryEntriesRevisionProvider.notifier).state++;

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dicts = ref.watch(dictionariesProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add to dictionary',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              widget.word,
              style: theme.textTheme.titleMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            dicts.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Error loading dictionaries: $e'),
              data: (list) => _buildDictionaryPicker(context, list),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _definitionCtrl,
              maxLines: null,
              minLines: 3,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Definition',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
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

  Widget _buildDictionaryPicker(BuildContext context, List<Dictionary> list) {
    // Filter the dropdown to dictionaries that are usable in this book's
    // context: globals + matching-series. Dictionaries scoped to a
    // *different* series are still visible but visually marked as
    // "(other series)" — and disabled — so the user understands why
    // they're listed without being able to mis-add to them.
    if (_selectedDictId == null) {
      _selectedDictId =
          list.isEmpty ? _newDictId : _firstUsableId(list) ?? _newDictId;
    }

    final isCreating = _selectedDictId == _newDictId;
    final canScope =
        widget.bookSeries != null && widget.bookSeries!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int>(
          initialValue: _selectedDictId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Dictionary',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final d in list)
              DropdownMenuItem(
                value: d.id,
                enabled: _isUsableInThisBook(d),
                child: _DictionaryRow(
                  dict: d,
                  usable: _isUsableInThisBook(d),
                ),
              ),
            const DropdownMenuItem(
              value: _newDictId,
              child: Row(
                children: [
                  Icon(Icons.add, size: 18),
                  SizedBox(width: 6),
                  Text('Create new dictionary'),
                ],
              ),
            ),
          ],
          onChanged: (v) => setState(() => _selectedDictId = v),
        ),
        if (isCreating) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _newNameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'New dictionary name',
              border: OutlineInputBorder(),
            ),
          ),
          if (canScope) ...[
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
                'When off, the dictionary applies everywhere.',
              ),
            ),
          ],
        ],
      ],
    );
  }

  bool _isUsableInThisBook(Dictionary d) {
    if (d.series == null) return true; // global
    return d.series == widget.bookSeries;
  }

  int? _firstUsableId(List<Dictionary> list) {
    for (final d in list) {
      if (_isUsableInThisBook(d) && d.id != null) return d.id;
    }
    return null;
  }
}

class _DictionaryRow extends StatelessWidget {
  const _DictionaryRow({required this.dict, required this.usable});
  final Dictionary dict;
  final bool usable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            dict.name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: usable ? null : theme.colorScheme.onSurface
                  .withValues(alpha: 0.45),
            ),
          ),
        ),
        if (dict.series != null) ...[
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary
                  .withValues(alpha: usable ? 0.12 : 0.05),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              dict.series!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary
                    .withValues(alpha: usable ? 1.0 : 0.5),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
