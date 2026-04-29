import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/navigation/main_drawer.dart';
import '../../library/providers/library_provider.dart';
import '../services/book_bundle_service.dart';

class ImportBundleScreen extends ConsumerStatefulWidget {
  const ImportBundleScreen({super.key});

  @override
  ConsumerState<ImportBundleScreen> createState() =>
      _ImportBundleScreenState();
}

class _ImportBundleScreenState
    extends ConsumerState<ImportBundleScreen> {
  final _service = BookBundleService();
  String? _pickedPath;
  BundlePreview? _preview;
  bool _busy = false;
  String? _stage;
  String? _error;

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() {
      _busy = true;
      _stage = 'Inspecting bundle';
      _error = null;
      _preview = null;
      _pickedPath = path;
    });
    try {
      final preview = await _service.previewBundle(path);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _busy = false;
        _stage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _busy = false;
        _stage = null;
      });
    }
  }

  Future<void> _import() async {
    if (_pickedPath == null) return;
    setState(() {
      _busy = true;
      _stage = null;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final summary = await _service.importBundle(
        _pickedPath!,
        onProgress: (s) => setState(() => _stage = s),
      );
      // Refresh the library so the new books show up immediately.
      ref.invalidate(libraryProvider);
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l.importBundleSummary(
              summary.booksAdded,
              summary.booksMerged,
              summary.citationsAdded,
              summary.notesAdded,
              summary.charactersAdded,
              summary.dictionaryEntriesAdded,
              summary.linksAdded,
            ),
          ),
          duration: const Duration(seconds: 8),
        ),
      );
      setState(() {
        _busy = false;
        _stage = null;
        _pickedPath = null;
        _preview = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _busy = false;
        _stage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    return Scaffold(
      drawer: const MainDrawer(currentRoute: '/import-bundle'),
      appBar: AppBar(title: Text(l.importBundleTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.importBundleIntro, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.folder_open),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(l.importBundlePick),
                ),
              ),
              const SizedBox(height: 16),
              if (_busy) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 6),
                Text(
                  _stage ?? 'Working…',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              if (_preview != null) ...[
                const SizedBox(height: 12),
                _Preview(
                  preview: _preview!,
                  onImport: _busy ? null : _import,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.preview, required this.onImport});

  final BundlePreview preview;
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              preview.rootTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${preview.bookCount} book(s) · '
              '${preview.citationCount} citation(s) · '
              '${preview.noteCount} note(s) · '
              '${preview.characterCount} character(s) · '
              '${preview.dictionaryCount} dictionary(ies) · '
              '${preview.linkCount} link(s)',
              style: theme.textTheme.bodyMedium,
            ),
            if (preview.includesProgress) ...[
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).importBundleProgressIncluded,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (preview.bookTitles.length > 1) ...[
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).importBundleBooksHeader,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              for (final t in preview.bookTitles)
                Text(
                  '• $t',
                  style: theme.textTheme.bodySmall,
                ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: onImport,
                child: Text(AppLocalizations.of(context).actionImport),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
