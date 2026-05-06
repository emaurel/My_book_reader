import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/navigation/main_drawer.dart';
import '../../bundles/presentation/widgets/share_bundle_dialog.dart';
import '../domain/book.dart';
import '../providers/library_provider.dart';
import 'widgets/book_edit_sheet.dart';
import 'widgets/book_grid_item.dart';
import 'widgets/book_info_sheet.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final l = AppLocalizations.of(context);

    return Scaffold(
      drawer: const MainDrawer(currentRoute: '/'),
      appBar: AppBar(
        title: Text(l.navLibrary),
        actions: [
          IconButton(
            icon: const Icon(Icons.travel_explore),
            tooltip: l.libraryScanTooltip,
            onPressed: () => _onScan(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l.libraryRefreshTooltip,
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
        label: Text(l.libraryAddBooks),
      ),
      body: library.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (books) {
          if (books.isEmpty) return const _EmptyState();
          return RefreshIndicator(
            onRefresh: () => ref.read(libraryProvider.notifier).refresh(),
            child: _SeriesGroupedLibrary(
              books: books,
              onOpen: (book) => context.push('/read/${book.id}'),
              onLongPress: (book) => _showBookActions(context, ref, book),
              onSeriesLongPress: (name, list) =>
                  _showSeriesActions(context, name, list),
            ),
          );
        },
      ),
    );
  }

  Future<void> _onImport(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    try {
      final added =
          await ref.read(libraryProvider.notifier).importFromPicker();
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            added == 0 ? l.libraryImportNone : l.libraryImportAdded(added),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.libraryImportFailed(e.toString()))),
      );
    }
  }

  Future<void> _onRefreshMetadata(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(minutes: 5),
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(l.libraryRefreshing),
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
            n == 0 ? l.libraryRefreshAllHave : l.libraryRefreshDone(n),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(l.libraryRefreshFailed(e.toString()))),
      );
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
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(minutes: 5),
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(l.libraryScanning),
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
            added == 0 ? l.libraryScanNoneFound : l.libraryScanAdded(added),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(l.libraryScanFailed(e.toString()))),
      );
    }
  }

  void _showSeriesActions(
    BuildContext context,
    String seriesName,
    List<Book> seriesBooks,
  ) {
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                seriesName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle:
                  Text(l.librarySeriesBooksCount(seriesBooks.length)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(l.actionShareSeriesBundle),
              onTap: () {
                Navigator.pop(sheetContext);
                showShareSeriesBundleDialog(
                  context,
                  seriesName: seriesName,
                  books: seriesBooks,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBookActions(BuildContext context, WidgetRef ref, Book book) {
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
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
              title: Text(l.actionOpen),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/read/${book.id}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l.actionBookInfo),
              onTap: () {
                Navigator.pop(sheetContext);
                _showBookInfo(context, book);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l.actionEditInfo),
              onTap: () {
                Navigator.pop(sheetContext);
                showBookEditSheet(context, book: book);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(l.actionShareBundle),
              onTap: () {
                Navigator.pop(sheetContext);
                showShareBundleDialog(context, book);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l.actionRemoveFromLibrary),
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

/// Library list grouped by `Book.series` (with a trailing "Other" group
/// for books without a series). Each group is a collapsible
/// ExpansionTile; books inside are sorted by `seriesNumber` ascending,
/// with un-numbered books falling back to alphabetical title order.
class _SeriesGroupedLibrary extends StatelessWidget {
  const _SeriesGroupedLibrary({
    required this.books,
    required this.onOpen,
    required this.onLongPress,
    required this.onSeriesLongPress,
  });

  final List<Book> books;
  final void Function(Book) onOpen;
  final void Function(Book) onLongPress;
  final void Function(String seriesName, List<Book> seriesBooks)
      onSeriesLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final groups = <String?, List<Book>>{};
    for (final book in books) {
      final raw = book.series?.trim();
      final key = (raw == null || raw.isEmpty) ? null : raw;
      (groups[key] ??= []).add(book);
    }
    for (final list in groups.values) {
      list.sort((a, b) {
        final an = a.seriesNumber;
        final bn = b.seriesNumber;
        if (an != null && bn != null) return an.compareTo(bn);
        if (an != null) return -1;
        if (bn != null) return 1;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    }
    final keys = groups.keys.toList()
      ..sort((a, b) {
        if (a == null && b == null) return 0;
        if (a == null) return 1; // Other last
        if (b == null) return -1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });

    return ListView(
      padding: EdgeInsets.fromLTRB(
        12,
        4,
        12,
        MediaQuery.viewPaddingOf(context).bottom + 96,
      ),
      children: [
        for (final series in keys)
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: true,
              tilePadding: const EdgeInsets.symmetric(horizontal: 4),
              childrenPadding: EdgeInsets.zero,
              title: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: series != null
                    ? () => onSeriesLongPress(series, groups[series]!)
                    : null,
                child: Text(
                  (series ?? l.libraryGroupOther).toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160,
                    childAspectRatio: 0.55,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: groups[series]!.length,
                  itemBuilder: (_, i) {
                    final book = groups[series]![i];
                    return BookGridItem(
                      book: book,
                      onTap: () => onOpen(book),
                      onLongPress: () => onLongPress(book),
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
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
              l.libraryEmptyTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l.libraryEmptyHint,
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
