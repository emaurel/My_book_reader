import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/navigation/main_drawer.dart';
import '../domain/dictionary.dart';
import '../providers/dictionary_provider.dart';
import 'widgets/dictionary_entry_card.dart';

class DictionariesScreen extends ConsumerWidget {
  const DictionariesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dicts = ref.watch(dictionariesProvider);
    return Scaffold(
      drawer: const MainDrawer(currentRoute: '/dictionaries'),
      appBar: AppBar(
        title: const Text('Dictionaries'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New dictionary',
            onPressed: () => _createDialog(context, ref),
          ),
        ],
      ),
      body: dicts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) return const _EmptyState();
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.viewPaddingOf(context).bottom + 24,
            ),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _DictionaryCard(dict: list[i]),
          );
        },
      ),
    );
  }

  Future<void> _createDialog(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NewDictionaryDialog(),
    );
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(dictionariesProvider.notifier).create(name: name);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create: $e')),
      );
    }
  }
}

/// Stateful so the [TextEditingController] is owned and disposed by the
/// dialog widget itself — disposing in the calling code after `await`
/// races the dialog's close animation and triggers
/// "TextEditingController used after disposed".
class _NewDictionaryDialog extends StatefulWidget {
  const _NewDictionaryDialog();

  @override
  State<_NewDictionaryDialog> createState() => _NewDictionaryDialogState();
}

class _NewDictionaryDialogState extends State<_NewDictionaryDialog> {
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
      title: const Text('New dictionary'),
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

class _DictionaryCard extends ConsumerWidget {
  const _DictionaryCard({required this.dict});

  final Dictionary dict;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      child: ExpansionTile(
        title: Row(
          children: [
            Flexible(
              child: Text(
                dict.name,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (dict.series != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  dict.series!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete dictionary',
              onPressed: () => _confirmDelete(context, ref),
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Consumer(
            builder: (_, ref, __) {
              final entries =
                  ref.watch(entriesForDictionaryProvider(dict.id!));
              return entries.when(
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
                        'No entries yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final e in list)
                        DictionaryEntryCard(
                          key: ValueKey(e.id),
                          header: e.word,
                          entry: e,
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Delete "${dict.name}"?'),
        content: const Text(
          'This removes the dictionary and every entry inside it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || dict.id == null) return;
    await ref.read(dictionariesProvider.notifier).remove(dict.id!);
    ref.read(dictionaryEntriesRevisionProvider.notifier).state++;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('No dictionaries yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'In the reader, long-press a word and tap "Dictionary" to add '
              'it. You\'ll be able to create your first dictionary from there.',
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
