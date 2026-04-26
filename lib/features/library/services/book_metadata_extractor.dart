import 'dart:io';
import 'dart:typed_data';

import 'package:epubx/epubx.dart' as epubx;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import '../domain/book.dart';

class ExtractedMetadata {
  ExtractedMetadata({
    this.title,
    this.author,
    this.description,
    this.series,
    this.seriesNumber,
    this.coverBytes,
  });

  final String? title;
  final String? author;
  final String? description;
  final String? series;
  final double? seriesNumber;
  final Uint8List? coverBytes;
}

class BookMetadataExtractor {
  Future<ExtractedMetadata> extract(String filePath, BookFormat format) async {
    try {
      switch (format) {
        case BookFormat.epub:
          return await _extractEpub(filePath);
        case BookFormat.pdf:
          return await _extractPdf(filePath);
        case BookFormat.txt:
        case BookFormat.azw:
          return ExtractedMetadata();
      }
    } catch (_) {
      return ExtractedMetadata();
    }
  }

  Future<ExtractedMetadata> _extractEpub(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final book = await epubx.EpubReader.readBook(bytes);

    final metadata = book.Schema?.Package?.Metadata;
    final title = book.Title ?? metadata?.Titles?.firstOrNull;
    final author = book.Author ??
        metadata?.Creators?.map((c) => c.Creator).whereType<String>().firstOrNull;
    final description =
        metadata?.Description?.trim().isNotEmpty == true
            ? metadata!.Description!.trim()
            : null;

    String? series;
    double? seriesNumber;
    final metaItems = metadata?.MetaItems ?? const [];
    for (final m in metaItems) {
      final name = m.Name?.toLowerCase();
      if (name == 'calibre:series') series = m.Content;
      if (name == 'calibre:series_index') {
        seriesNumber = double.tryParse(m.Content ?? '');
      }
    }

    Uint8List? coverBytes;
    final cover = book.CoverImage;
    if (cover != null) {
      final encoded = img.encodeJpg(cover, quality: 85);
      coverBytes = Uint8List.fromList(encoded);
    }

    return ExtractedMetadata(
      title: title,
      author: author,
      description: description,
      series: series,
      seriesNumber: seriesNumber,
      coverBytes: coverBytes,
    );
  }

  Future<ExtractedMetadata> _extractPdf(String filePath) async {
    final doc = await PdfDocument.openFile(filePath);
    Uint8List? coverBytes;
    try {
      final page = await doc.getPage(1);
      try {
        final aspect = page.height / page.width;
        const targetWidth = 320;
        final targetHeight = (targetWidth * aspect).round();
        final image = await page.render(
          width: targetWidth.toDouble(),
          height: targetHeight.toDouble(),
          format: PdfPageImageFormat.jpeg,
          backgroundColor: '#FFFFFF',
        );
        coverBytes = image?.bytes;
      } finally {
        await page.close();
      }
    } finally {
      await doc.close();
    }
    return ExtractedMetadata(coverBytes: coverBytes);
  }

  Future<String> saveCover(int bookId, Uint8List bytes) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'covers'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final path = p.join(dir.path, 'book_$bookId.jpg');
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }
}
