import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../library/domain/book.dart';
import '../../../library/providers/library_provider.dart';

/// Returns the picked book's id, or null if the user dismissed.
/// [excludeBookId] hides the currently-open source book from the list
/// so users can't link a book to itself.
Future<int?> showLinkBookPickerSheet(
  BuildContext context, {
  required int excludeBookId,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _LinkBookPickerSheet(excludeBookId: excludeBookId),
  );
}

class _LinkBookPickerSheet extends ConsumerStatefulWidget {
  const _LinkBookPickerSheet({required this.excludeBookId});

  final int excludeBookId;

  @override
  ConsumerState<_LinkBookPickerSheet> createState() =>
      _LinkBookPickerSheetState();
}

class _LinkBookPickerSheetState
    extends ConsumerState<_LinkBookPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final library = ref.watch(libraryProvider);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Link to book',
                style: theme.textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                autofocus: false,
                decoration: const InputDecoration(
                  hintText: 'Search by title or author',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: library.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (books) {
                  final filtered = books.where((b) {
                    if (b.id == widget.excludeBookId) return false;
                    if (_query.isEmpty) return true;
                    final hay =
                        '${b.title} ${b.author ?? ''}'.toLowerCase();
                    return hay.contains(_query);
                  }).toList();
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        _query.isEmpty
                            ? 'No other books in your library'
                            : 'No matches',
                        style: theme.textTheme.bodyMedium,
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final book = filtered[i];
                      return ListTile(
                        leading: _Cover(book: book),
                        title: Text(
                          book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: book.author != null
                            ? Text(
                                book.author!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        onTap: () => Navigator.pop(context, book.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final coverPath = book.coverPath;
    if (coverPath != null && File(coverPath).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          File(coverPath),
          width: 36,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _CoverPlaceholder(),
        ),
      );
    }
    return const _CoverPlaceholder();
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 50,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(Icons.book_outlined, size: 18),
    );
  }
}
