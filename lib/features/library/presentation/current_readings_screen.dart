import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/navigation/main_drawer.dart';
import '../domain/book.dart';
import '../providers/library_provider.dart';
import 'widgets/book_edit_sheet.dart';
import 'widgets/book_grid_item.dart';
import 'widgets/book_info_sheet.dart';

void _showBookActions(BuildContext context, WidgetRef ref, Book book) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              book.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(book.author ?? book.format.name.toUpperCase()),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Open'),
            onTap: () {
              Navigator.pop(sheetContext);
              context.push('/read/${book.id}');
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Book info'),
            onTap: () {
              Navigator.pop(sheetContext);
              showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (_) => BookInfoSheet(book: book),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit info'),
            onTap: () {
              Navigator.pop(sheetContext);
              showBookEditSheet(context, book: book);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Remove from library'),
            onTap: () async {
              Navigator.pop(sheetContext);
              if (book.id != null) {
                await ref
                    .read(libraryProvider.notifier)
                    .remove(book.id!);
              }
            },
          ),
        ],
      ),
    ),
  );
}

class CurrentReadingsScreen extends ConsumerWidget {
  const CurrentReadingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(currentReadingsProvider);
    return Scaffold(
      drawer: const MainDrawer(currentRoute: '/current'),
      appBar: AppBar(title: const Text('Continue reading')),
      body: books.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) return const _EmptyState();
          return GridView.builder(
            padding: EdgeInsets.fromLTRB(
              12,
              12,
              12,
              MediaQuery.viewPaddingOf(context).bottom + 24,
            ),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
              childAspectRatio: 0.55,
              crossAxisSpacing: 8,
              mainAxisSpacing: 12,
            ),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final book = list[i];
              return BookGridItem(
                book: book,
                onTap: () => context.push('/read/${book.id}'),
                onLongPress: () => _showBookActions(context, ref, book),
              );
            },
          );
        },
      ),
    );
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
              Icons.auto_stories_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text("Nothing in progress",
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Books you\'ve started but not yet finished will show up '
              'here, ordered by the last time you opened them.',
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
