import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/dictionary_provider.dart';
import 'dictionary_entry_card.dart';

/// Bottom sheet that shows all definitions for [word]. Each definition
/// is one entry; can have multiple if the same word lives in several
/// dictionaries. Allows editing or deleting entries inline (no nested
/// dialog — that combination is unstable when the keyboard animates).
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
                      DictionaryEntryCard(
                        key: ValueKey(ewd.entry.id),
                        header: ewd.dictionaryName ?? '—',
                        entry: ewd.entry,
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
