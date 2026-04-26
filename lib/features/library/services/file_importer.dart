import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/book.dart';

class ImportedFile {
  ImportedFile({
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

class FileImporter {
  static const _allowedExtensions = ['epub', 'pdf', 'txt'];

  /// Opens the file picker and copies selected books into app-private storage
  /// (so they survive across permission changes and aren't subject to scoped
  /// storage gotchas). Returns successfully imported files.
  Future<List<ImportedFile>> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      withData: false,
    );

    if (result == null || result.files.isEmpty) return [];

    final imported = <ImportedFile>[];
    final libraryDir = await _libraryDir();

    for (final picked in result.files) {
      final source = picked.path;
      if (source == null) continue;

      final ext = p.extension(picked.name).replaceAll('.', '').toLowerCase();
      final format = BookFormat.fromExtension(ext);
      if (format == null) continue;

      final destPath = await _uniqueDestPath(libraryDir, picked.name);
      final destFile = await File(source).copy(destPath);
      final size = await destFile.length();

      imported.add(
        ImportedFile(
          path: destFile.path,
          title: p.basenameWithoutExtension(picked.name),
          format: format,
          sizeBytes: size,
        ),
      );
    }

    return imported;
  }

  Future<Directory> _libraryDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'library'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> _uniqueDestPath(Directory dir, String originalName) async {
    final base = p.basenameWithoutExtension(originalName);
    final ext = p.extension(originalName);
    var candidate = p.join(dir.path, '$base$ext');
    var counter = 1;
    while (await File(candidate).exists()) {
      candidate = p.join(dir.path, '$base ($counter)$ext');
      counter++;
    }
    return candidate;
  }
}
