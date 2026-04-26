import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../library/domain/book.dart';
import '../../library/providers/library_provider.dart';
import '../providers/reader_controls_provider.dart';
import '../providers/reader_progress_provider.dart';
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
    _applySystemUi();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Clear progress so the next reader open doesn't briefly show stale state.
    Future.microtask(
      () => ref.read(readerProgressProvider.notifier).state = null,
    );
    super.dispose();
  }

  /// Hide the bottom Android nav bar when chrome is dismissed for a
  /// distraction-free reading experience. Status bar (top) stays so the
  /// user can still see time / battery. Restored on screen exit.
  void _applySystemUi() {
    if (_chromeVisible) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [SystemUiOverlay.top],
      );
    }
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

  void _toggleChrome() {
    setState(() => _chromeVisible = !_chromeVisible);
    _applySystemUi();
  }

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
      extendBody: true,
      bottomNavigationBar:
          _chromeVisible ? _ReaderProgressBar(theme: settings.theme) : null,
      appBar: _chromeVisible
          ? AppBar(
              backgroundColor: bg,
              foregroundColor: settings.theme.foreground,
              shape: Border(
                bottom: BorderSide(
                  color: settings.theme.foreground.withValues(alpha: 0.18),
                  width: 1,
                ),
              ),
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

class _ReaderProgressBar extends ConsumerWidget {
  const _ReaderProgressBar({required this.theme});

  final ReaderTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(readerProgressProvider);
    final fg = theme.foreground;

    return Container(
      decoration: BoxDecoration(
        color: theme.background,
        border: Border(
          top: BorderSide(
            color: fg.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (progress?.fraction ?? 0).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: fg.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(fg.withValues(alpha: 0.85)),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  progress?.label ?? '—',
                  style: TextStyle(
                    fontSize: 13,
                    color: fg.withValues(alpha: 0.85),
                  ),
                ),
                Text(
                  '${((progress?.fraction ?? 0) * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 13,
                    color: fg.withValues(alpha: 0.85),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
