import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReaderProgress {
  const ReaderProgress({required this.fraction, required this.label});

  /// 0.0..1.0 — overall position through the book.
  final double fraction;

  /// Format-specific label shown next to the bar
  /// (e.g. "12 / 304" for paged formats; "Ch 3/17 · p 2/8" for EPUB).
  final String label;
}

/// Each viewer updates this on every page change so the reader screen's
/// chrome can render a single, unified progress bar.
final readerProgressProvider = StateProvider<ReaderProgress?>((_) => null);
