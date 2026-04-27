import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../library/domain/book.dart';
import '../../services/book_bundle_service.dart';

/// Dialog for exporting a single book + everything it touches as a
/// shareable .zip "Book bundle".
Future<void> showShareBundleDialog(
  BuildContext context,
  Book book,
) {
  return _showBundleDialog(
    context,
    rootBookIds: [book.id!],
    label: book.title,
    titleSuffix: '',
  );
}

/// Same dialog, but seeded with every book in a series as a root —
/// linked-books expansion (when enabled) still pulls in cross-series
/// references.
Future<void> showShareSeriesBundleDialog(
  BuildContext context, {
  required String seriesName,
  required List<Book> books,
}) {
  final ids = books
      .where((b) => b.id != null)
      .map((b) => b.id!)
      .toList();
  if (ids.isEmpty) return Future.value();
  return _showBundleDialog(
    context,
    rootBookIds: ids,
    label: seriesName,
    titleSuffix: ' (${ids.length} books)',
  );
}

Future<void> _showBundleDialog(
  BuildContext context, {
  required List<int> rootBookIds,
  required String label,
  required String titleSuffix,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ShareBundleDialog(
      rootBookIds: rootBookIds,
      label: label,
      titleSuffix: titleSuffix,
    ),
  );
}

class _ShareBundleDialog extends ConsumerStatefulWidget {
  const _ShareBundleDialog({
    required this.rootBookIds,
    required this.label,
    required this.titleSuffix,
  });

  final List<int> rootBookIds;
  final String label;
  final String titleSuffix;

  @override
  ConsumerState<_ShareBundleDialog> createState() =>
      _ShareBundleDialogState();
}

class _ShareBundleDialogState
    extends ConsumerState<_ShareBundleDialog> {
  bool _includeLinked = true;
  bool _includeProgress = false;
  bool _busy = false;
  String? _stage;

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _stage = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await BookBundleService().exportBundle(
        rootBookIds: widget.rootBookIds,
        includeLinkedBooks: _includeLinked,
        includeProgress: _includeProgress,
        filenameHint: widget.label,
        onProgress: (s) => setState(() => _stage = s),
      );
      if (!mounted) return;
      Navigator.pop(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Bundle saved to ${result.savedPath}'),
          duration: const Duration(seconds: 6),
        ),
      );
      await Share.shareXFiles(
        [XFile(result.savedPath)],
        subject: 'Book bundle: ${widget.label}',
        text: 'Book bundle: ${widget.label}',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stage = null;
      });
      messenger.showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Share book bundle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bundles "${widget.label}"${widget.titleSuffix} together '
            'with citations, notes, characters, dictionary entries, '
            'and links into a single .zip you can share.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Include linked books'),
            subtitle: const Text(
              'Recursively pull in every book reachable through links',
            ),
            value: _includeLinked,
            onChanged: _busy
                ? null
                : (v) => setState(() => _includeLinked = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Include reading progress'),
            subtitle: const Text(
              'Off by default — useful when sharing with friends',
            ),
            value: _includeProgress,
            onChanged: _busy
                ? null
                : (v) => setState(() => _includeProgress = v),
          ),
          if (_busy) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
            const SizedBox(height: 4),
            Text(
              _stage ?? 'Working…',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _export,
          child: const Text('Export'),
        ),
      ],
    );
  }
}
