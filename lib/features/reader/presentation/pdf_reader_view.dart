import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../library/domain/book.dart';
import '../../library/providers/library_provider.dart';
import '../providers/reader_controls_provider.dart';
import '../providers/reader_progress_provider.dart';
import '../providers/reader_settings_provider.dart';

class PdfReaderView extends ConsumerStatefulWidget {
  const PdfReaderView({super.key, required this.book});

  final Book book;

  @override
  ConsumerState<PdfReaderView> createState() => _PdfReaderViewState();
}

class _PdfReaderViewState extends ConsumerState<PdfReaderView> {
  late final PdfController _controller;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _wakeEnabled = false;

  @override
  void initState() {
    super.initState();
    final initialPage = widget.book.position?['page'] as int? ?? 1;
    _controller = PdfController(
      document: PdfDocument.openFile(widget.book.filePath),
      initialPage: initialPage,
    );
    _currentPage = initialPage;
    _applyWakelock();
  }

  void _applyWakelock() {
    final keepOn = ref.read(readerSettingsProvider).keepScreenOn;
    if (keepOn != _wakeEnabled) {
      _wakeEnabled = keepOn;
      WakelockPlus.toggle(enable: keepOn);
    }
  }

  void _onPageChanged(int page) {
    if (_totalPages == 0) return;
    _currentPage = page;
    final progress = (page / _totalPages).clamp(0.0, 1.0);
    ref.read(readerProgressProvider.notifier).state = ReaderProgress(
      fraction: progress,
      label: '$page / $_totalPages',
    );
    if (widget.book.id != null) {
      ref.read(bookRepositoryProvider).updateProgress(
        widget.book.id!,
        progress: progress,
        position: {'page': page},
      );
    }
    setState(() {});
  }

  void _onDocumentLoaded(PdfDocument doc) {
    setState(() => _totalPages = doc.pagesCount);
    final fraction = (_currentPage / _totalPages).clamp(0.0, 1.0);
    ref.read(readerProgressProvider.notifier).state = ReaderProgress(
      fraction: fraction,
      label: '$_currentPage / $_totalPages',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(readerControlsProvider.notifier).state = ReaderControls(
        goPrev: _goPrev,
        goNext: _goNext,
      );
    });
  }

  void _goPrev() {
    _controller.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _goNext() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_wakeEnabled) WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    _applyWakelock();

    return Container(
      color: settings.theme.background,
      child: PdfView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        onPageChanged: _onPageChanged,
        onDocumentLoaded: _onDocumentLoaded,
        backgroundDecoration: BoxDecoration(
          color: settings.theme.background,
        ),
        builders: PdfViewBuilders<DefaultBuilderOptions>(
          options: const DefaultBuilderOptions(),
          documentLoaderBuilder: (_) =>
              const Center(child: CircularProgressIndicator()),
          pageLoaderBuilder: (_) =>
              const Center(child: CircularProgressIndicator()),
          errorBuilder: (_, error) =>
              Center(child: Text('Failed to load PDF: $error')),
        ),
      ),
    );
  }
}
