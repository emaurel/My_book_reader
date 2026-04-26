import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../library/domain/book.dart';
import '../../library/providers/library_provider.dart';
import '../providers/reader_controls_provider.dart';
import '../providers/reader_settings_provider.dart';
import 'widgets/reader_settings_sheet.dart';
import 'azw_reader_view.dart';
import 'epub_reader_view.dart';
import 'pdf_reader_view.dart';
import 'txt_reader_view.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.bookId});

  final int bookId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  Book? _book;
  bool _loading = true;
  String? _error;
  bool _chromeVisible = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(bookRepositoryProvider);
      final book = await repo.getById(widget.bookId);
      if (!mounted) return;
      setState(() {
        _book = book;
        _loading = false;
        _error = book == null ? 'Book not found' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _toggleChrome() => setState(() => _chromeVisible = !_chromeVisible);

  void _onTapUp(TapUpDetails details) {
    final width = MediaQuery.sizeOf(context).width;
    final x = details.globalPosition.dx;
    final controls = ref.read(readerControlsProvider);

    if (x < width * 0.3) {
      controls.goPrev?.call();
    } else if (x > width * 0.7) {
      controls.goNext?.call();
    } else {
      _toggleChrome();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    final bg = settings.theme.background;

    if (_loading) {
      return Scaffold(
        backgroundColor: bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _book == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error ?? 'Unknown error')),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      extendBodyBehindAppBar: true,
      appBar: _chromeVisible
          ? AppBar(
              backgroundColor: bg.withValues(alpha: 0.92),
              foregroundColor: settings.theme.foreground,
              titleTextStyle: Theme.of(context)
                  .appBarTheme
                  .titleTextStyle
                  ?.copyWith(color: settings.theme.foreground),
              title: Text(
                _book!.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: _showSettingsSheet,
                ),
              ],
            )
          : null,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: _onTapUp,
        child: _buildViewer(),
      ),
    );
  }

  Widget _buildViewer() {
    final book = _book!;
    switch (book.format) {
      case BookFormat.epub:
        return EpubReaderView(book: book, onMenuTap: _toggleChrome);
      case BookFormat.pdf:
        return PdfReaderView(book: book);
      case BookFormat.txt:
        return TxtReaderView(book: book);
      case BookFormat.azw:
        return AzwReaderView(book: book);
    }
  }

  void _showSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const ReaderSettingsSheet(),
    );
  }
}
