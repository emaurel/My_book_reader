import 'dart:io';

import 'package:kindle_unpack/kindle_unpack.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ConvertedKindleBook {
  ConvertedKindleBook({
    required this.epubPath,
    required this.title,
    required this.sizeBytes,
  });

  final String epubPath;
  final String title;
  final int sizeBytes;
}

/// Wraps `kindle_unpack` to turn a MOBI / AZW / AZW3 / KF8 file into an
/// EPUB 3 saved under the app's `library/` directory. The rest of the
/// pipeline then treats the result as a normal EPUB book — no
/// AZW-specific code paths needed past this point.
class KindleConverter {
  /// Returns null if the source can't be parsed (encrypted, malformed,
  /// or otherwise unsupported by `kindle_unpack`). Caller falls back to
  /// keeping the book as `BookFormat.azw` for the placeholder reader.
  Future<ConvertedKindleBook?> convert(String azwPath) async {
    try {
      final bytes = await File(azwPath).readAsBytes();
      final book = KindleBook.fromBytes(bytes);
      final epubBytes = book.toEpub();

      final libraryDir = await _libraryDir();
      final baseName = p.basenameWithoutExtension(azwPath);
      final destPath = await _uniqueEpubPath(libraryDir, baseName);
      await File(destPath).writeAsBytes(epubBytes, flush: true);

      final title = book.title.trim().isNotEmpty ? book.title.trim() : baseName;

      return ConvertedKindleBook(
        epubPath: destPath,
        title: title,
        sizeBytes: epubBytes.length,
      );
    } on KindleUnpackException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Directory> _libraryDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'library'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> _uniqueEpubPath(Directory dir, String baseName) async {
    var candidate = p.join(dir.path, '$baseName.epub');
    var counter = 1;
    while (await File(candidate).exists()) {
      candidate = p.join(dir.path, '$baseName ($counter).epub');
      counter++;
    }
    return candidate;
  }
}
