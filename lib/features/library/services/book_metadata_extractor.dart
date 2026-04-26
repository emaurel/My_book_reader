import 'dart:io';
import 'dart:typed_data';

import 'package:epubx/epubx.dart' as epubx;
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

    // Kindle Store convention: series isn't a discrete EXTH record; it's
    // baked into the title as "Title (SeriesName Book N)". When no
    // explicit series metadata is present, parse it out and clean the
    // title.
    var cleanedTitle = title;
    if (title != null && series == null) {
      final m = _seriesInTitlePattern.firstMatch(title);
      if (m != null) {
        cleanedTitle = m.group(1)?.trim();
        series = m.group(2)?.trim();
        seriesNumber = double.tryParse(m.group(3) ?? '');
      }
    }

    final coverHref = _findCoverHref(book);
    final coverBytes = coverHref == null ? null : _imageBytesFor(book, coverHref);

    return ExtractedMetadata(
      title: cleanedTitle,
      author: author,
      description: description,
      series: series,
      seriesNumber: seriesNumber,
      coverBytes: coverBytes,
    );
  }

  /// Matches "Some Book Title (Some Series Name Book 3)" or
  /// "Some Title (Some Series, Book 3.5)" or "Some Title (Series #3)".
  /// Group 1: clean title. Group 2: series name. Group 3: series number.
  static final RegExp _seriesInTitlePattern = RegExp(
    r'^(.+?)\s*\(([^()]+?),?\s+(?:Book|Vol\.?|Volume|#)\s*(\d+(?:\.\d+)?)\)\s*$',
    caseSensitive: false,
  );

  /// Find the cover image's href in the manifest. Walks three strategies in
  /// order: EPUB-3 `properties="cover-image"`, EPUB-2 `<meta name="cover">`
  /// pointing at a manifest item id, and finally a filename heuristic.
  String? _findCoverHref(epubx.EpubBook book) {
    final pkg = book.Schema?.Package;
    final manifest = pkg?.Manifest;

    if (manifest != null) {
      for (final item in manifest.Items ?? const []) {
        if ((item.Properties ?? '').toLowerCase().contains('cover-image')) {
          return item.Href;
        }
      }
    }

    String? coverItemId;
    final metaItems = pkg?.Metadata?.MetaItems ?? const [];
    for (final m in metaItems) {
      if (m.Name?.toLowerCase() == 'cover') {
        coverItemId = m.Content;
        break;
      }
    }
    if (coverItemId != null && manifest != null) {
      for (final item in manifest.Items ?? const []) {
        if (item.Id == coverItemId) return item.Href;
      }
    }

    final imgs = book.Content?.Images;
    if (imgs != null) {
      for (final key in imgs.keys) {
        if (key.toLowerCase().contains('cover')) return key;
      }
    }

    // 4. Last resort: the largest image in the book. Covers are almost
    // always the highest-resolution asset (full-page illustrations are
    // 50–500 KB; inline figures are usually under 20 KB), so this is a
    // reliable fallback for EPUBs that don't declare a cover anywhere.
    if (imgs != null && imgs.isNotEmpty) {
      String? largestKey;
      var largestSize = 0;
      for (final entry in imgs.entries) {
        final size = entry.value.Content?.length ?? 0;
        if (size > largestSize) {
          largestSize = size;
          largestKey = entry.key;
        }
      }
      if (largestKey != null) return largestKey;
    }

    return null;
  }

  /// Lookup raw image bytes by manifest href. Tries an exact key match
  /// first, then a basename match (paths in EPUBs are sometimes relative
  /// to the OPF and don't match `Content.Images` keys exactly).
  Uint8List? _imageBytesFor(epubx.EpubBook book, String href) {
    final imgs = book.Content?.Images ?? const <String, epubx.EpubByteContentFile>{};
    final exact = imgs[href];
    if (exact?.Content != null) {
      return Uint8List.fromList(exact!.Content!);
    }
    final basename = href.split('/').last;
    for (final entry in imgs.entries) {
      if (entry.key.endsWith(basename) && entry.value.Content != null) {
        return Uint8List.fromList(entry.value.Content!);
      }
    }
    return null;
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
