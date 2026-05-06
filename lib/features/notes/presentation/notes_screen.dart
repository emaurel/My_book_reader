import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/navigation/main_drawer.dart';
import '../../library/providers/library_provider.dart';
import '../domain/note.dart';
import '../providers/note_provider.dart';
import 'widgets/add_note_sheet.dart';

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider);
    return Scaffold(
      drawer: const MainDrawer(currentRoute: '/notes'),
      appBar: AppBar(title: Text(AppLocalizations.of(context).navNotes)),
      body: notes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
            itemBuilder: (_, i) => _NoteCard(note: items[i]),
          );
        },
      ),
    );
  }
}

class _NoteCard extends ConsumerWidget {
  const _NoteCard({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final canOpen = note.bookId != null;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: canOpen
            ? () => context.push('/read/${note.bookId}')
            : null,
        onLongPress: () => _showActions(context, ref),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.noteText,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(
                '“${note.selectedText}”',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              const SizedBox(height: 6),
              FutureBuilder<String?>(
                future: _resolveBookTitle(ref, note.bookId),
                builder: (_, snap) => Text(
                  '${snap.data ?? '—'} · ${_fmtDate(note.updatedAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
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
              leading: const Icon(Icons.edit_outlined),
              title: Text(AppLocalizations.of(context).actionEdit),
              onTap: () async {
                Navigator.pop(sheetContext);
                if (note.id == null) return;
                await showEditNoteSheet(
                  context,
                  noteId: note.id!,
                  selectedText: note.selectedText,
                  currentText: note.noteText,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(AppLocalizations.of(context).actionDelete),
              onTap: () async {
                Navigator.pop(sheetContext);
                if (note.id != null) {
                  await ref
                      .read(notesProvider.notifier)
                      .remove(note.id!);
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
              Icons.sticky_note_2_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).notesEmptyTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).notesEmptyHint,
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
