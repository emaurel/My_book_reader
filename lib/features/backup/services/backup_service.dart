import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/database_helper.dart';

/// SharedPreferences keys we persist in the backup. Any key not listed
/// here is left alone on restore (so future migrations don't wipe the
/// user's other state).
const _backedUpPrefKeys = <String>[
  'app_theme_mode',
  'library.showDocuments',
  'reader.fontSize',
  'reader.lineHeight',
  'reader.padding',
  'reader.fontFamily',
  'reader.theme',
  'reader.keepScreenOn',
  'book_links.graph_positions',
  'book_links.graph_transform',
];

const _dbFilename = 'book_reader.db';
const _libraryDirName = 'library';
const _coversDirName = 'covers';

class BackupService {
  /// Build a zip containing the DB, library files, covers, and the
  /// app's SharedPreferences. Writes it under
  /// `<appdocs>/backups/book-reader-backup-YYYY-MM-DD-HHMM.zip` and
  /// returns the absolute path so the caller can hand it to share_plus.
  Future<String> exportToFile({
    void Function(String stage)? onProgress,
  }) async {
    onProgress?.call('Preparing');
    final base = await getApplicationDocumentsDirectory();
    final archive = Archive();

    onProgress?.call('Adding database');
    final dbFile = File(p.join(base.path, _dbFilename));
    if (await dbFile.exists()) {
      final bytes = await dbFile.readAsBytes();
      archive.addFile(ArchiveFile(_dbFilename, bytes.length, bytes));
    }

    onProgress?.call('Adding books');
    await _addDirectoryToArchive(
      archive,
      Directory(p.join(base.path, _libraryDirName)),
      _libraryDirName,
    );

    onProgress?.call('Adding covers');
    await _addDirectoryToArchive(
      archive,
      Directory(p.join(base.path, _coversDirName)),
      _coversDirName,
    );

    onProgress?.call('Adding preferences');
    final prefs = await SharedPreferences.getInstance();
    final prefsMap = <String, Object>{};
    for (final key in _backedUpPrefKeys) {
      final v = prefs.get(key);
      if (v != null) prefsMap[key] = v;
    }
    final prefsBytes = utf8.encode(jsonEncode(prefsMap));
    archive.addFile(
      ArchiveFile('prefs.json', prefsBytes.length, prefsBytes),
    );

    final manifest = {
      'schemaVersion': 1,
      'dbVersion': DatabaseHelper.dbVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );

    onProgress?.call('Compressing');
    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw StateError('ZipEncoder produced no bytes');
    }

    final filename = 'book-reader-backup-${_dateStamp()}.zip';
    final destPath = await _writeBackupBytes(filename, zipBytes, base);
    onProgress?.call('Done');
    return destPath;
  }

  /// Try the public `Download/` folder first (so the file picker can
  /// see it on restore); fall back to app-private docs if the storage
  /// permission isn't granted.
  Future<String> _writeBackupBytes(
    String filename,
    List<int> bytes,
    Directory appDocsBase,
  ) async {
    const publicDownloads = '/storage/emulated/0/Download';
    final dir = Directory(publicDownloads);
    if (await dir.exists()) {
      try {
        final destPath = p.join(publicDownloads, filename);
        await File(destPath).writeAsBytes(bytes, flush: true);
        return destPath;
      } on FileSystemException {
        // Fall through to private storage on permission denial.
      }
    }
    final backupsDir = Directory(p.join(appDocsBase.path, 'backups'));
    if (!await backupsDir.exists()) {
      await backupsDir.create(recursive: true);
    }
    final destPath = p.join(backupsDir.path, filename);
    await File(destPath).writeAsBytes(bytes, flush: true);
    return destPath;
  }

  /// Replace the current DB / library / covers / prefs with the
  /// contents of [zipPath]. Returns counts so the caller can show a
  /// summary. Caller is responsible for forcing the user to restart
  /// the app afterwards (Riverpod caches don't know to refresh).
  Future<RestoreSummary> restoreFromFile(
    String zipPath, {
    void Function(String stage)? onProgress,
  }) async {
    onProgress?.call('Reading backup');
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final manifestEntry = archive.findFile('manifest.json');
    if (manifestEntry == null) {
      throw const FormatException(
        'Not a Book Reader backup (manifest.json missing)',
      );
    }
    final manifest =
        jsonDecode(utf8.decode(manifestEntry.content as List<int>))
            as Map<String, dynamic>;
    final backupDbVersion = manifest['dbVersion'] as int? ?? 0;
    if (backupDbVersion > DatabaseHelper.dbVersion) {
      throw FormatException(
        'Backup was made with a newer app version '
        '(DB v$backupDbVersion vs. installed v${DatabaseHelper.dbVersion}). '
        'Update the app and try again.',
      );
    }

    onProgress?.call('Closing database');
    await DatabaseHelper.instance.close();

    onProgress?.call('Wiping current data');
    final base = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(base.path, _dbFilename));
    if (await dbFile.exists()) await dbFile.delete();
    final libDir = Directory(p.join(base.path, _libraryDirName));
    if (await libDir.exists()) await libDir.delete(recursive: true);
    final coversDir = Directory(p.join(base.path, _coversDirName));
    if (await coversDir.exists()) await coversDir.delete(recursive: true);

    onProgress?.call('Extracting backup');
    var extractedFiles = 0;
    for (final file in archive) {
      if (!file.isFile) continue;
      if (file.name == 'manifest.json' || file.name == 'prefs.json') {
        continue;
      }
      final destPath = p.join(base.path, file.name);
      await Directory(p.dirname(destPath)).create(recursive: true);
      await File(destPath).writeAsBytes(
        file.content as List<int>,
        flush: true,
      );
      extractedFiles++;
    }

    onProgress?.call('Restoring preferences');
    final prefsEntry = archive.findFile('prefs.json');
    if (prefsEntry != null) {
      final prefsMap = jsonDecode(
        utf8.decode(prefsEntry.content as List<int>),
      ) as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      for (final key in _backedUpPrefKeys) {
        await prefs.remove(key);
      }
      for (final entry in prefsMap.entries) {
        final v = entry.value;
        if (v is bool) {
          await prefs.setBool(entry.key, v);
        } else if (v is int) {
          await prefs.setInt(entry.key, v);
        } else if (v is double) {
          await prefs.setDouble(entry.key, v);
        } else if (v is String) {
          await prefs.setString(entry.key, v);
        } else if (v is List) {
          await prefs.setStringList(entry.key, v.cast<String>());
        }
      }
    }

    onProgress?.call('Done');
    return RestoreSummary(
      filesRestored: extractedFiles,
      backupCreatedAt: manifest['createdAt']?.toString(),
    );
  }

  Future<void> _addDirectoryToArchive(
    Archive archive,
    Directory dir,
    String prefix,
  ) async {
    if (!await dir.exists()) return;
    await for (final entity in dir.list(recursive: false)) {
      if (entity is! File) continue;
      final bytes = await entity.readAsBytes();
      final name = '$prefix/${p.basename(entity.path)}';
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }
  }

  String _dateStamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${two(n.month)}-${two(n.day)}'
        '-${two(n.hour)}${two(n.minute)}';
  }
}

class RestoreSummary {
  RestoreSummary({required this.filesRestored, this.backupCreatedAt});

  final int filesRestored;
  final String? backupCreatedAt;
}
