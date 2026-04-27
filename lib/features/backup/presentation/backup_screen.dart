import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../../../shared/navigation/main_drawer.dart';
import '../services/backup_service.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _service = BackupService();
  bool _busy = false;
  String? _stage;

  Future<void> _export() async {
    if (Platform.isAndroid) {
      final granted = await _ensureStoragePermission();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Storage permission denied — backup will be saved in '
              'app-private storage and will only be accessible via '
              'Share.',
            ),
          ),
        );
      }
    }
    setState(() {
      _busy = true;
      _stage = null;
    });
    try {
      final path = await _service.exportToFile(
        onProgress: (s) => setState(() => _stage = s),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup written to $path'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Copy path',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: path));
            },
          ),
        ),
      );
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'Book Reader backup',
        text: 'Book Reader backup',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _stage = null;
        });
      }
    }
  }

  Future<bool> _ensureStoragePermission() async {
    final current = await Permission.manageExternalStorage.status;
    if (current.isGranted) return true;
    final result = await Permission.manageExternalStorage.request();
    return result.isGranted;
  }

  Future<void> _restore() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replace all data?'),
        content: const Text(
          'Restoring will permanently overwrite your current library, '
          'citations, characters, dictionary, and reader settings with '
          'the contents of the backup. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _stage = null;
    });
    try {
      final summary = await _service.restoreFromFile(
        path,
        onProgress: (s) => setState(() => _stage = s),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore complete'),
          content: Text(
            'Restored ${summary.filesRestored} files'
            '${summary.backupCreatedAt != null ? '\nBackup taken ${summary.backupCreatedAt}' : ''}'
            '\n\nClose and reopen the app to load the restored data.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _stage = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      drawer: const MainDrawer(currentRoute: '/backup'),
      appBar: AppBar(title: const Text('Backup & restore')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Export bundles your library files, covers, database '
                '(books, citations, characters, dictionary, progress) '
                'and reader settings into a single .zip you can share '
                'or save off-device.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _export,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Export backup'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _restore,
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Restore from backup'),
                ),
              ),
              const SizedBox(height: 24),
              if (_busy)
                Column(
                  children: [
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(
                      _stage ?? 'Working…',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              const Spacer(),
              Text(
                'Restoring overwrites all current data. The app must be '
                'closed and reopened afterwards for the change to take '
                'effect.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
