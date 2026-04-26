import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import '../domain/book.dart';

class ScannedFile {
  ScannedFile({
    required this.path,
    required this.title,
    required this.format,
    required this.sizeBytes,
  });

  final String path;
  final String title;
  final BookFormat format;
  final int sizeBytes;
}

class ScanPermissionDeniedException implements Exception {
  const ScanPermissionDeniedException();
  @override
  String toString() =>
      'Permission to read device storage was not granted. '
      'Enable "All files access" for Book Reader in Android settings.';
}

class BookScanner {
  /// Common folders books typically live in. Anything else is left to the
  /// manual file picker.
  static const _commonDirs = <String>[
    '/storage/emulated/0/Download',
    '/storage/emulated/0/Downloads',
    '/storage/emulated/0/Documents',
    '/storage/emulated/0/Books',
    '/storage/emulated/0/eBooks',
  ];

  Future<bool> ensureAccess() async {
    if (!Platform.isAndroid) return true;
    final current = await Permission.manageExternalStorage.status;
    if (current.isGranted) return true;
    final result = await Permission.manageExternalStorage.request();
    return result.isGranted;
  }

  Future<List<ScannedFile>> scan() => compute(_scanIsolate, _commonDirs);
}

List<ScannedFile> _scanIsolate(List<String> dirs) {
  final found = <ScannedFile>[];
  for (final path in dirs) {
    final dir = Directory(path);
    if (!dir.existsSync()) continue;
    try {
      for (final entity
          in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final ext =
            p.extension(entity.path).replaceAll('.', '').toLowerCase();
        final fmt = BookFormat.fromExtension(ext);
        if (fmt == null) continue;
        try {
          found.add(ScannedFile(
            path: entity.path,
            title: p.basenameWithoutExtension(entity.path),
            format: fmt,
            sizeBytes: entity.lengthSync(),
          ));
        } catch (_) {
          // Unreadable file, skip.
        }
      }
    } catch (_) {
      // Unreadable directory, skip.
    }
  }
  return found;
}
