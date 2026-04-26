import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../library/domain/book.dart';
import '../../library/providers/library_provider.dart';
import '../providers/reader_controls_provider.dart';
import '../providers/reader_settings_provider.dart';

/// Paginated TXT viewer. The full text is loaded once, then split into
/// pages on-demand based on the available size and current text style.
/// Pages are recomputed when settings change.
class TxtReaderView extends ConsumerStatefulWidget {
  const TxtReaderView({super.key, required this.book});

  final Book book;

  @override
  ConsumerState<TxtReaderView> createState() => _TxtReaderViewState();
}

class _TxtReaderViewState extends ConsumerState<TxtReaderView> {
  String? _text;
  String? _error;
  PageController? _pageController;
  List<String> _pages = const [];
  Size? _lastSize;
  TextStyle? _lastStyle;
  double? _lastPadding;
  bool _wakeEnabled = false;
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _loadText();
    _applyWakelock();
  }

  Future<void> _loadText() async {
    try {
      final raw = await File(widget.book.filePath).readAsString();
      if (!mounted) return;
      setState(() => _text = raw);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  void _applyWakelock() {
    final keepOn = ref.read(readerSettingsProvider).keepScreenOn;
    if (keepOn != _wakeEnabled) {
      _wakeEnabled = keepOn;
      WakelockPlus.toggle(enable: keepOn);
    }
  }

  TextStyle _styleFor(ReaderSettings s) {
    return GoogleFonts.getFont(
      s.fontFamily,
      fontSize: s.fontSize,
      height: s.lineHeight,
      color: s.theme.foreground,
    );
  }

  void _maybeRepaginate(Size size, TextStyle style, double padding) {
    if (_text == null) return;
    if (_lastSize == size &&
        _lastStyle == style &&
        _lastPadding == padding &&
        _pages.isNotEmpty) {
      return;
    }

    final available = Size(
      size.width - (padding * 2),
      size.height - 80, // breathing room for top/bottom chrome
    );

    final pages = _paginate(_text!, style, available);
    final initialPage = _initialPage(pages.length);

    setState(() {
      _pages = pages;
      _lastSize = size;
      _lastStyle = style;
      _lastPadding = padding;
      _pageController?.dispose();
      _pageController = PageController(initialPage: initialPage);
    });
    _registerControls();
  }

  void _registerControls() {
    ref.read(readerControlsProvider.notifier).state = ReaderControls(
      goPrev: _goPrev,
      goNext: _goNext,
    );
  }

  void _goPrev() {
    final c = _pageController;
    if (c == null || !c.hasClients) return;
    c.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _goNext() {
    final c = _pageController;
    if (c == null || !c.hasClients) return;
    c.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  int _initialPage(int total) {
    final stored = widget.book.position?['page'] as int?;
    if (stored != null) return stored.clamp(0, total - 1);
    final progress = widget.book.progress.clamp(0.0, 1.0);
    return (progress * total).floor().clamp(0, total - 1);
  }

  /// Greedy paginator: walks paragraphs, then word-wraps overflow.
  List<String> _paginate(String text, TextStyle style, Size area) {
    final pages = <String>[];
    final paragraphs = text.split(RegExp(r'\n\s*\n'));
    final buffer = StringBuffer();

    bool fits(String candidate) {
      final tp = TextPainter(
        text: TextSpan(text: candidate, style: style),
        textDirection: TextDirection.ltr,
        maxLines: null,
      )..layout(maxWidth: area.width);
      return tp.size.height <= area.height;
    }

    void flush() {
      if (buffer.isNotEmpty) {
        pages.add(buffer.toString().trimRight());
        buffer.clear();
      }
    }

    for (final raw in paragraphs) {
      final para = raw.trim();
      if (para.isEmpty) continue;

      final attempt =
          buffer.isEmpty ? para : '${buffer.toString()}\n\n$para';

      if (fits(attempt)) {
        buffer
          ..clear()
          ..write(attempt);
      } else {
        // Current page is full, push it.
        flush();

        // Now: does the paragraph alone fit on a fresh page?
        if (fits(para)) {
          buffer.write(para);
        } else {
          // Word-by-word fill, splitting paragraph across pages.
          final words = para.split(' ');
          var line = StringBuffer();
          for (final word in words) {
            final next = line.isEmpty ? word : '$line $word';
            if (fits(next)) {
              line
                ..clear()
                ..write(next);
            } else {
              if (line.isNotEmpty) {
                pages.add(line.toString());
                line = StringBuffer(word);
              } else {
                // Single huge word — push as-is to avoid an infinite loop.
                pages.add(word);
                line = StringBuffer();
              }
            }
          }
          if (line.isNotEmpty) buffer.write(line);
        }
      }
    }
    flush();
    if (pages.isEmpty) pages.add('');
    return pages;
  }

  void _onPageChanged(int page) {
    if (widget.book.id == null || _pages.isEmpty) return;
    final progress = (page + 1) / _pages.length;

    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(bookRepositoryProvider).updateProgress(
        widget.book.id!,
        progress: progress.clamp(0.0, 1.0),
        position: {'page': page},
      );
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _pageController?.dispose();
    if (_wakeEnabled) WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    _applyWakelock();

    if (_error != null) {
      return Center(child: Text('Failed to load: $_error'));
    }
    if (_text == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final style = _styleFor(settings);

    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _maybeRepaginate(
            constraints.biggest,
            style,
            settings.horizontalPadding,
          );
        });

        if (_pages.isEmpty || _pageController == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (_, i) => Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: settings.horizontalPadding,
                    vertical: 24,
                  ),
                  child: Text(_pages[i], style: style),
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: AnimatedBuilder(
                animation: _pageController!,
                builder: (_, __) {
                  final page = _pageController!.hasClients &&
                          _pageController!.page != null
                      ? _pageController!.page!.round() + 1
                      : 1;
                  return Text(
                    '$page / ${_pages.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: settings.theme.foreground.withValues(alpha: 0.6),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
