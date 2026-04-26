import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/book.dart';

class BookGridItem extends StatelessWidget {
  const BookGridItem({
    super.key,
    required this.book,
    required this.onTap,
    required this.onLongPress,
  });

  final Book book;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _Cover(book: book),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (book.author != null && book.author!.isNotEmpty)
              Text(
                book.author!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (book.progress > 0) ...[
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: book.progress.clamp(0, 1),
                  minHeight: 3,
                  backgroundColor:
                      theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final coverPath = book.coverPath;
    if (coverPath != null && File(coverPath).existsSync()) {
      return Image.file(
        File(coverPath),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _Placeholder(book: book),
      );
    }
    return _Placeholder(book: book);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _paletteFor(book.title);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatBadge(book),
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            book.title,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  String _formatBadge(Book b) => b.format.name.toUpperCase();

  static List<Color> _paletteFor(String seed) {
    // Deterministic palette per title so a book always looks the same.
    final palettes = <List<Color>>[
      [const Color(0xFF6750A4), const Color(0xFF9A82DB)],
      [const Color(0xFF1F6FEB), const Color(0xFF58A6FF)],
      [const Color(0xFFB85450), const Color(0xFFE07856)],
      [const Color(0xFF2E7D32), const Color(0xFF66BB6A)],
      [const Color(0xFF455A64), const Color(0xFF78909C)],
      [const Color(0xFFAD1457), const Color(0xFFEC407A)],
    ];
    final hash =
        seed.codeUnits.fold<int>(0, (acc, c) => (acc + c) & 0x7fffffff);
    return palettes[hash % palettes.length];
  }
}
