import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../library/providers/library_provider.dart';
import '../../domain/book_link.dart';
import '../../providers/book_link_provider.dart';

/// Modal that shows all links involving [bookId] — both outgoing and
/// incoming — with each row tappable to navigate to the other end.
/// Used by the graph view's node-tap handler.
Future<void> showBookLinksSheet(BuildContext context, int bookId) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _BookLinksSheet(bookId: bookId),
  );
}

class _BookLinksSheet extends ConsumerWidget {
  const _BookLinksSheet({required this.bookId});

  final int bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final allLinks = ref.watch(bookLinksProvider);
    final maxHeight = MediaQuery.of(context).size.height * 0.8;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: allLinks.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text('Error: $e')),
          ),
          data: (items) {
            final outgoing =
                items.where((l) => l.sourceBookId == bookId).toList();
            final incoming =
                items.where((l) => l.targetBookId == bookId).toList();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: FutureBuilder<String?>(
                    future: _resolveTitle(ref, bookId),
                    builder: (_, snap) => Text(
                      snap.data ?? 'Book',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (outgoing.isEmpty && incoming.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: Text('No links')),
                          ),
                        if (outgoing.isNotEmpty) ...[
                          const _SectionHeader(
                            label: 'Links from this book',
                          ),
                          ..._buildLinkRows(
                            context,
                            ref,
                            outgoing,
                            otherEnd: 'target',
                          ),
                        ],
                        if (incoming.isNotEmpty) ...[
                          const _SectionHeader(
                            label: 'Links to this book',
                          ),
                          ..._buildLinkRows(
                            context,
                            ref,
                            incoming,
                            otherEnd: 'source',
                          ),
                        ],
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildLinkRows(
    BuildContext context,
    WidgetRef ref,
    List<BookLink> links, {
    required String otherEnd,
  }) {
    return links.map((link) {
      final otherId = otherEnd == 'target'
          ? link.targetBookId
          : link.sourceBookId;
      return ListTile(
        title: Text(
          '“${link.label}”',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: FutureBuilder<String?>(
          future: _resolveTitle(ref, otherId),
          builder: (_, snap) => Text(
            otherEnd == 'target'
                ? '→ ${snap.data ?? '—'}'
                : '← ${snap.data ?? '—'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          context.push('/read/$otherId');
        },
      );
    }).toList();
  }

  Future<String?> _resolveTitle(WidgetRef ref, int id) async {
    final book = await ref.read(bookRepositoryProvider).getById(id);
    return book?.title;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
