import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/book.dart';
import '../../providers/library_provider.dart';

/// Bottom sheet for editing the editable metadata of a book — title,
/// author, series, series number, and description. File / format /
/// progress are intentionally not exposed here (those come from the
/// file itself or are tracked automatically).
Future<bool?> showBookEditSheet(
  BuildContext context, {
  required Book book,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetCtx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom,
      ),
      child: _BookEditSheet(book: book),
    ),
  );
}

class _BookEditSheet extends ConsumerStatefulWidget {
  const _BookEditSheet({required this.book});
  final Book book;

  @override
  ConsumerState<_BookEditSheet> createState() => _BookEditSheetState();
}

class _BookEditSheetState extends ConsumerState<_BookEditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _author;
  late final TextEditingController _series;
  late final TextEditingController _seriesNumber;
  late final TextEditingController _description;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.book.title);
    _author = TextEditingController(text: widget.book.author ?? '');
    _series = TextEditingController(text: widget.book.series ?? '');
    _seriesNumber = TextEditingController(
      text: widget.book.seriesNumber == null
          ? ''
          : _fmtNum(widget.book.seriesNumber!),
    );
    _description =
        TextEditingController(text: widget.book.description ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _series.dispose();
    _seriesNumber.dispose();
    _description.dispose();
    super.dispose();
  }

  String _fmtNum(double n) =>
      n == n.truncate() ? n.toInt().toString() : n.toString();

  Future<void> _save() async {
    final newTitle = _title.text.trim();
    if (newTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title cannot be empty.')),
      );
      return;
    }
    final rawNumber = _seriesNumber.text.trim();
    double? seriesNumber;
    if (rawNumber.isNotEmpty) {
      seriesNumber = double.tryParse(rawNumber.replaceAll(',', '.'));
      if (seriesNumber == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Series number must be a number (e.g. 1, 1.5).'),
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);

    final author = _author.text.trim();
    final series = _series.text.trim();
    final description = _description.text.trim();

    // Construct directly (rather than via copyWith) so that clearing a
    // field in the form actually persists as NULL — copyWith uses `??`
    // and would silently keep the old value.
    final book = widget.book;
    final updated = Book(
      id: book.id,
      title: newTitle,
      author: author.isEmpty ? null : author,
      filePath: book.filePath,
      format: book.format,
      coverPath: book.coverPath,
      fileSize: book.fileSize,
      addedAt: book.addedAt,
      lastOpenedAt: book.lastOpenedAt,
      progress: book.progress,
      position: book.position,
      description: description.isEmpty ? null : description,
      series: series.isEmpty ? null : series,
      seriesNumber: seriesNumber,
      originalPath: book.originalPath,
    );

    try {
      await ref.read(bookRepositoryProvider).update(updated);
      ref.invalidate(libraryProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit book',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _author,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Author',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _series,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Series',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _seriesNumber,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9.,]'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: '#',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: null,
              minLines: 3,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _saving ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
