import 'dart:convert';

enum BookFormat {
  epub,
  pdf,
  txt,
  azw;

  static BookFormat? fromExtension(String ext) {
    switch (ext.toLowerCase().replaceAll('.', '')) {
      case 'epub':
        return BookFormat.epub;
      case 'pdf':
        return BookFormat.pdf;
      case 'txt':
        return BookFormat.txt;
      case 'azw':
      case 'azw3':
      case 'mobi':
        return BookFormat.azw;
      default:
        return null;
    }
  }
}

class Book {
  Book({
    this.id,
    required this.title,
    this.author,
    required this.filePath,
    required this.format,
    this.coverPath,
    this.fileSize,
    required this.addedAt,
    this.lastOpenedAt,
    this.progress = 0.0,
    this.position,
    this.description,
    this.series,
    this.seriesNumber,
    this.originalPath,
  });

  final int? id;
  final String title;
  final String? author;
  final String filePath;
  final BookFormat format;
  final String? coverPath;
  final int? fileSize;
  final DateTime addedAt;
  final DateTime? lastOpenedAt;
  final double progress;
  final Map<String, dynamic>? position;
  final String? description;
  final String? series;
  final double? seriesNumber;

  /// Path on the source device when the book required conversion (e.g.
  /// the original AZW3 in /sdcard/Download before kindle_unpack produced
  /// the EPUB at [filePath]). Used to dedupe future device scans so the
  /// same source file isn't re-converted on every scan. Null when no
  /// conversion happened — [filePath] is then both the source and the
  /// path on disk we read from.
  final String? originalPath;

  Book copyWith({
    int? id,
    String? title,
    String? author,
    String? filePath,
    BookFormat? format,
    String? coverPath,
    int? fileSize,
    DateTime? addedAt,
    DateTime? lastOpenedAt,
    double? progress,
    Map<String, dynamic>? position,
    String? description,
    String? series,
    double? seriesNumber,
    String? originalPath,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      filePath: filePath ?? this.filePath,
      format: format ?? this.format,
      coverPath: coverPath ?? this.coverPath,
      fileSize: fileSize ?? this.fileSize,
      addedAt: addedAt ?? this.addedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      progress: progress ?? this.progress,
      position: position ?? this.position,
      description: description ?? this.description,
      series: series ?? this.series,
      seriesNumber: seriesNumber ?? this.seriesNumber,
      originalPath: originalPath ?? this.originalPath,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'author': author,
        'file_path': filePath,
        'format': format.name,
        'cover_path': coverPath,
        'file_size': fileSize,
        'added_at': addedAt.millisecondsSinceEpoch,
        'last_opened_at': lastOpenedAt?.millisecondsSinceEpoch,
        'progress': progress,
        'position': position == null ? null : jsonEncode(position),
        'description': description,
        'series': series,
        'series_number': seriesNumber,
        'original_path': originalPath,
      };

  factory Book.fromMap(Map<String, dynamic> m) => Book(
        id: m['id'] as int?,
        title: m['title'] as String,
        author: m['author'] as String?,
        filePath: m['file_path'] as String,
        format: BookFormat.values.firstWhere(
          (f) => f.name == m['format'],
          orElse: () => BookFormat.txt,
        ),
        coverPath: m['cover_path'] as String?,
        fileSize: m['file_size'] as int?,
        addedAt:
            DateTime.fromMillisecondsSinceEpoch(m['added_at'] as int),
        lastOpenedAt: m['last_opened_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['last_opened_at'] as int),
        progress: (m['progress'] as num?)?.toDouble() ?? 0.0,
        position: m['position'] == null
            ? null
            : jsonDecode(m['position'] as String) as Map<String, dynamic>,
        description: m['description'] as String?,
        series: m['series'] as String?,
        seriesNumber: (m['series_number'] as num?)?.toDouble(),
        originalPath: m['original_path'] as String?,
      );
}
