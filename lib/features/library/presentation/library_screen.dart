import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/book.dart';
import '../providers/library_provider.dart';
import 'widgets/book_grid_item.dart';
import 'widgets/book_info_sheet.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final sort = ref.watch(librarySortProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          PopupMenuButton<LibrarySort>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            initialValue: sort,
            onSelected: (s) =>
                ref.read(librarySortProvider.notifier).state = s,
            itemBuilder: (_) => LibrarySort.values
                .map((s) => PopupMenuItem(value: s, child: Text(s.label)))
                .toList(),
          ),
          IconButton(
            icon: const Icon(Icons.travel_explore),
            tooltip: 'Scan device for books',
            onPressed: () => _onScan(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh covers & metadata',
            onPressed: () => _onRefreshMetadata(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _onImport(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add books'),
      ),
      body: library.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (books) {
          if (books.isEmpty) return const _EmptyState();
          return RefreshIndicator(
            onRefresh: () => ref.read(libraryProvider.notifier).refresh(),
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                childAspectRatio: 0.55,
                crossAxisSpacing: 8,
                mainAxisSpacing: 12,
              ),
              itemCount: books.length,
              itemBuilder: (_, i) {
                final book = books[i];
                return BookGridItem(
                  book: book,
                  onTap: () => context.push('/read/${book.id}'),
                  onLongPress: () => _showBookActions(context, ref, book),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _onImport(BuildContext context, WidgetRef ref) async {
    try {
      final added =
          await ref.read(libraryProvider.notifier).importFromPicker();
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            added == 0
                ? 'No new books added.'
                : 'Added $added book${added == 1 ? '' : 's'}.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }

  Future<void> _onRefreshMetadata(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        duration: Duration(minutes: 5),
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Refreshing covers & metadata…'),
          ],
        ),
      ),
    );
    try {
      final n =
          await ref.read(libraryProvider.notifier).refreshAllMetadata();
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            n == 0
                ? 'All books already have metadata.'
                : 'Refreshed $n book${n == 1 ? '' : 's'}.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('Refresh failed: $e')));
    }
  }

  void _showBookInfo(BuildContext context, Book book) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => BookInfoSheet(book: book),
    );
  }

  Future<void> _onScan(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        duration: Duration(minutes: 5),
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Scanning device for books…'),
          ],
        ),
      ),
    );
    try {
      final added = await ref.read(libraryProvider.notifier).scanDevice();
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            added == 0
                ? 'No new books found.'
                : 'Found and added $added book${added == 1 ? '' : 's'}.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('Scan failed: $e')));
    }
  }

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
                _showBookInfo(context, book);
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
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Your library is empty',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Add books" to import EPUB, PDF, or TXT files.',
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
