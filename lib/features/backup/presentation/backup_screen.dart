import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../../../l10n/app_localizations.dart';
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
    final l = AppLocalizations.of(context);
    if (Platform.isAndroid) {
      final granted = await _ensureStoragePermission();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.backupPermissionWarning)),
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
          content: Text(l.backupWrittenTo(path)),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: l.actionCopyPath,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: path));
            },
          ),
        ),
      );
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'Lorekeeper backup',
        text: 'Lorekeeper backup',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.backupExportFailed(e.toString()))),
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
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.backupReplaceTitle),
        content: Text(l.backupReplaceBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.actionRestore),
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
          title: Text(l.backupRestoreCompleteTitle),
          content: Text(
            l.backupRestoreCompleteBody(
              summary.filesRestored,
              summary.backupCreatedAt != null
                  ? l.backupTakenAtSuffix(summary.backupCreatedAt!)
                  : '',
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.actionOK),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.backupRestoreFailed(e.toString()))),
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
    final l = AppLocalizations.of(context);
    return Scaffold(
      drawer: const MainDrawer(currentRoute: '/backup'),
      appBar: AppBar(title: Text(l.navBackup)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.backupIntro, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _export,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(l.backupExportButton),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _restore,
                icon: const Icon(Icons.cloud_download_outlined),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(l.backupRestoreButton),
                ),
              ),
              const SizedBox(height: 24),
              if (_busy)
                Column(
                  children: [
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(
                      _stage ?? l.readerWorking,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              const Spacer(),
              Text(
                l.backupRestoreFooter,
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
