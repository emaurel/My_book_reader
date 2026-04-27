import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReaderControls {
  const ReaderControls({
    this.goPrev,
    this.goNext,
    this.jumpToChapter,
    this.chapterTitles = const [],
    this.currentChapterIndex,
  });

  final VoidCallback? goPrev;
  final VoidCallback? goNext;

  /// Jump straight to a chapter, ignoring the saved page position.
  /// Null when the current viewer doesn't have a meaningful chapter
  /// concept (TXT, PDF).
  final void Function(int chapterIndex)? jumpToChapter;

  /// Flat list of chapter titles (sub-chapters included). Empty when
  /// the viewer has no table of contents to expose.
  final List<String> chapterTitles;

  /// Where the reader is right now in [chapterTitles].
  final int? currentChapterIndex;
}

/// Each viewer registers its prev/next callbacks here on init.
/// `ReaderScreen` reads these to dispatch tap-left / tap-right gestures
/// and the chapter-picker.
final readerControlsProvider =
    StateProvider<ReaderControls>((_) => const ReaderControls());
