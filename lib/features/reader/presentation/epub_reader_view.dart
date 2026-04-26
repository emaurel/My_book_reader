import 'dart:io';

import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../library/data/book_repository.dart';
import '../../library/domain/book.dart';
import '../../library/providers/library_provider.dart';
import '../providers/reader_settings_provider.dart';

class EpubReaderView extends ConsumerStatefulWidget {
  const EpubReaderView({super.key, required this.book});

  final Book book;

  @override
  ConsumerState<EpubReaderView> createState() => _EpubReaderViewState();
}

class _EpubReaderViewState extends ConsumerState<EpubReaderView> {
  late final EpubController _controller;
  bool _wakeEnabled = false;

  @override
  void initState() {
    super.initState();
    _controller = EpubController(
      document: EpubDocument.openFile(File(widget.book.filePath)),
      epubCfi: widget.book.position?['cfi'] as String?,
    );
    _controller.currentValueListenable.addListener(_onPositionChanged);
    _applyWakelock();
  }

  void _applyWakelock() {
    final keepOn = ref.read(readerSettingsProvider).keepScreenOn;
    if (keepOn != _wakeEnabled) {
      _wakeEnabled = keepOn;
      WakelockPlus.toggle(enable: keepOn);
    }
  }

  void _onPositionChanged() {
    final value = _controller.currentValueListenable.value;
    if (value == null || widget.book.id == null) return;

    final cfi = _controller.generateEpubCfi();
    final progress = (value.progress ?? 0).clamp(0.0, 100.0) / 100.0;

    ref.read(bookRepositoryProvider).updateProgress(
      widget.book.id!,
      progress: progress,
      position: {'cfi': cfi},
    );
  }

  @override
  void dispose() {
    _controller.currentValueListenable.removeListener(_onPositionChanged);
    _controller.dispose();
    if (_wakeEnabled) WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    _applyWakelock();

    return EpubView(
      controller: _controller,
      builders: EpubViewBuilders<DefaultBuilderOptions>(
        options: DefaultBuilderOptions(
          textStyle: TextStyle(
            fontSize: settings.fontSize,
            height: settings.lineHeight,
            color: settings.theme.foreground,
            fontFamily: settings.fontFamily,
          ),
        ),
        chapterDividerBuilder: (chapter) => Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          alignment: Alignment.center,
          child: Text(
            chapter.Title ?? '',
            style: TextStyle(
              fontSize: settings.fontSize + 4,
              fontWeight: FontWeight.w700,
              color: settings.theme.foreground,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        loaderBuilder: (_) => const Center(child: CircularProgressIndicator()),
        errorBuilder: (e) => Center(child: Text('Could not open EPUB: $e')),
      ),
    );
  }
}
