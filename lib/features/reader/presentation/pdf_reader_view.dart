import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../library/data/book_repository.dart';
import '../../library/domain/book.dart';
import '../../library/providers/library_provider.dart';
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
    if (widget.book.id == null || _totalPages == 0) return;
    _currentPage = page;
    final progress = page / _totalPages;
    ref.read(bookRepositoryProvider).updateProgress(
      widget.book.id!,
      progress: progress.clamp(0.0, 1.0),
      position: {'page': page},
    );
    setState(() {});
  }

  void _onDocumentLoaded(PdfDocument doc) {
    setState(() => _totalPages = doc.pagesCount);
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

    return Stack(
      children: [
        Container(
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
            loaderSwitchDuration: const Duration(milliseconds: 200),
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
        ),
        if (_totalPages > 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
