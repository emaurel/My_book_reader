import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/note_provider.dart';

/// Bottom sheet for creating a new note. Returns the new note's id
/// on save, or null on dismiss.
Future<int?> showAddNoteSheet(
  BuildContext context, {
  required String selectedText,
  int? bookId,
  int? chapterIndex,
  int? charStart,
  int? charEnd,
}) {
  return showModalBottomSheet<int?>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: _AddNoteSheet(
        selectedText: selectedText,
        bookId: bookId,
        chapterIndex: chapterIndex,
        charStart: charStart,
        charEnd: charEnd,
      ),
    ),
  );
}

/// Sheet for editing an existing note. Returns true if the note was
/// modified (updated or deleted).
Future<bool> showEditNoteSheet(
  BuildContext context, {
  required int noteId,
  required String selectedText,
  required String currentText,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: _AddNoteSheet(
        editingNoteId: noteId,
        selectedText: selectedText,
        initialText: currentText,
      ),
    ),
  );
  return result == true;
}

class _AddNoteSheet extends ConsumerStatefulWidget {
  const _AddNoteSheet({
    required this.selectedText,
    this.bookId,
    this.chapterIndex,
    this.charStart,
    this.charEnd,
    this.editingNoteId,
    this.initialText,
  });

  final String selectedText;
  final int? bookId;
  final int? chapterIndex;
  final int? charStart;
  final int? charEnd;
  final int? editingNoteId;
  final String? initialText;

  @override
  ConsumerState<_AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends ConsumerState<_AddNoteSheet> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    if (widget.editingNoteId != null) {
      await ref
          .read(notesProvider.notifier)
          .updateText(widget.editingNoteId!, text);
      if (!mounted) return;
      Navigator.pop(context, true);
    } else {
      final id = await ref.read(notesProvider.notifier).add(
            bookId: widget.bookId,
            chapterIndex: widget.chapterIndex,
            charStart: widget.charStart,
            charEnd: widget.charEnd,
            selectedText: widget.selectedText,
            noteText: text,
          );
      if (!mounted) return;
      Navigator.pop(context, id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.editingNoteId != null ? 'Edit note' : 'Add note',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '“${widget.selectedText}”',
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLines: null,
            minLines: 3,
            decoration: const InputDecoration(
              hintText: 'Your note',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(widget.editingNoteId != null ? 'Save' : 'Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
