import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/book.dart';

class BookInfoSheet extends StatelessWidget {
  const BookInfoSheet({super.key, required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _coverImage(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              book.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (book.author != null && book.author!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'by ${book.author}',
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
            ],
            if (book.series != null && book.series!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                book.seriesNumber != null
                    ? '${book.series} #${_fmtNum(book.seriesNumber!)}'
                    : book.series!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _MetaRow(label: 'Format', value: book.format.name.toUpperCase()),
            if (book.fileSize != null)
              _MetaRow(label: 'Size', value: _fmtSize(book.fileSize!)),
            _MetaRow(label: 'Added', value: _fmtDate(book.addedAt)),
            if (book.lastOpenedAt != null)
              _MetaRow(
                  label: 'Last opened', value: _fmtDate(book.lastOpenedAt!)),
            if (book.progress > 0)
              _MetaRow(
                label: 'Progress',
                value: '${(book.progress * 100).toStringAsFixed(0)}%',
              ),
            if (book.description != null &&
                book.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Description',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: muted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                book.description!.trim(),
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _coverImage() {
    final cover = book.coverPath;
    if (cover != null && File(cover).existsSync()) {
      return Image.file(File(cover), fit: BoxFit.cover);
    }
    return Container(color: const Color(0xFF6750A4));
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtNum(double n) =>
      n == n.truncate() ? n.toInt().toString() : n.toString();
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
