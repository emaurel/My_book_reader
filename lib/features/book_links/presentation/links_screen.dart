import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/navigation/main_drawer.dart';
import '../../library/providers/library_provider.dart';
import '../domain/book_link.dart';
import '../providers/book_link_provider.dart';
import 'links_graph_view.dart';

class LinksScreen extends ConsumerWidget {
  const LinksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(bookLinksProvider);
    final l = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        drawer: const MainDrawer(currentRoute: '/links'),
        appBar: AppBar(
          title: Text(l.navLinks),
          bottom: TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.account_tree_outlined),
                text: l.linksTabGraph,
              ),
              Tab(icon: const Icon(Icons.list), text: l.linksTabList),
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            const LinksGraphView(),
            links.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (items) {
                if (items.isEmpty) return const _EmptyState();
                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    MediaQuery.viewPaddingOf(context).bottom + 24,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _LinkCard(link: items[i]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkCard extends ConsumerWidget {
  const _LinkCard({required this.link});

  final BookLink link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/read/${link.targetBookId}'),
        onLongPress: () => _showActions(context, ref),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<_LinkBookTitles>(
                future: _resolveTitles(ref, link),
                builder: (_, snap) {
                  final src = snap.data?.source ?? '—';
                  final tgt = snap.data?.target ?? '—';
                  return RichText(
                    text: TextSpan(
                      style: theme.textTheme.titleMedium,
                      children: [
                        TextSpan(text: src),
                        TextSpan(
                          text: '  →  ',
                          style: TextStyle(color: muted),
                        ),
                        TextSpan(
                          text: tgt,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                '“${link.label}”',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              Text(
                _fmtDate(link.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<_LinkBookTitles> _resolveTitles(WidgetRef ref, BookLink l) async {
    final repo = ref.read(bookRepositoryProvider);
    final src = await repo.getById(l.sourceBookId);
    final tgt = await repo.getById(l.targetBookId);
    return _LinkBookTitles(
      source: src?.title,
      target: tgt?.title,
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  void _showActions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(AppLocalizations.of(context).linksOpenSource),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/read/${link.sourceBookId}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.east),
              title: Text(AppLocalizations.of(context).linksOpenTarget),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/read/${link.targetBookId}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(AppLocalizations.of(context).actionDelete),
              onTap: () async {
                Navigator.pop(sheetContext);
                if (link.id != null) {
                  await ref
                      .read(bookLinksProvider.notifier)
                      .remove(link.id!);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkBookTitles {
  _LinkBookTitles({this.source, this.target});
  final String? source;
  final String? target;
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
              Icons.link,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).linksEmptyTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).linksEmptyHint,
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
