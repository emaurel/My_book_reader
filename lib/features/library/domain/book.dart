import 'dart:convert';

enum BookFormat {
  epub,
  pdf,
  txt;

  static BookFormat? fromExtension(String ext) {
    switch (ext.toLowerCase().replaceAll('.', '')) {
      case 'epub':
        return BookFormat.epub;
      case 'pdf':
        return BookFormat.pdf;
      case 'txt':
        return BookFormat.txt;
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
  final double progress; // 0.0 - 1.0
  final Map<String, dynamic>? position; // format-specific (page, cfi, offset)

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
      );
}
