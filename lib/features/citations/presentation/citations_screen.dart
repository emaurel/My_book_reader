import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/navigation/main_drawer.dart';
import '../../library/providers/library_provider.dart';
import '../domain/citation.dart';
import '../providers/citation_provider.dart';

class CitationsScreen extends ConsumerWidget {
  const CitationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final citations = ref.watch(citationsProvider);
    return Scaffold(
      drawer: const MainDrawer(currentRoute: '/citations'),
      appBar: AppBar(title: Text(AppLocalizations.of(context).navCitations)),
      body: citations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) return const _EmptyState();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _CitationCard(citation: items[i]),
          );
        },
      ),
    );
  }
}

class _CitationCard extends ConsumerWidget {
  const _CitationCard({required this.citation});

  final Citation citation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final canOpen = citation.bookId != null && citation.id != null;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: canOpen
            ? () => context.push(
                  '/read/${citation.bookId}?citation=${citation.id}',
                )
            : null,
        onLongPress: () => _showActions(context, ref),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '“${citation.text}”',
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
              ),
              const SizedBox(height: 8),
              FutureBuilder<String?>(
                future: _resolveBookTitle(ref, citation.bookId),
                builder: (_, snap) {
                  final source = snap.data ?? '—';
                  return Text(
                    '$source · ${_fmtDate(citation.createdAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _resolveBookTitle(WidgetRef ref, int? bookId) async {
    if (bookId == null) return null;
    final book = await ref.read(bookRepositoryProvider).getById(bookId);
    return book?.title;
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _showActions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: Text(AppLocalizations.of(context).actionCopyText),
              onTap: () async {
                final l = AppLocalizations.of(context);
                Navigator.pop(sheetContext);
                await Clipboard.setData(ClipboardData(text: citation.text));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.citationsCopiedToClipboard)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(AppLocalizations.of(context).actionDelete),
              onTap: () async {
                Navigator.pop(sheetContext);
                if (citation.id != null) {
                  await ref
                      .read(citationsProvider.notifier)
                      .remove(citation.id!);
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
              Icons.format_quote_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).citationsEmptyTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).citationsEmptyHint,
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
