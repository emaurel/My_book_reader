import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:epubx/epubx.dart' as epubx;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../library/domain/book.dart';
import '../../library/providers/library_provider.dart';
import '../providers/reader_controls_provider.dart';
import '../providers/reader_progress_provider.dart';
import '../providers/reader_settings_provider.dart';

/// EPUB viewer that renders chapter HTML inside a WebView using CSS multi-column
/// layout, so each screen is exactly one page (no scrolling). Taps on the left
/// or right third flip pages; tapping the middle toggles the reader chrome via
/// [onMenuTap]. At chapter boundaries the prev/next gesture rolls into the
/// adjacent chapter automatically.
class EpubReaderView extends ConsumerStatefulWidget {
  const EpubReaderView({
    super.key,
    required this.book,
    required this.onMenuTap,
  });

  final Book book;
  final VoidCallback onMenuTap;

  @override
  ConsumerState<EpubReaderView> createState() => _EpubReaderViewState();
}

class _EpubReaderViewState extends ConsumerState<EpubReaderView> {
  late final WebViewController _web;
  List<epubx.EpubChapter> _chapters = const [];
  int _chapterIndex = 0;
  int _pageInChapter = 0;
  int _pagesInChapter = 1;
  bool _wakeEnabled = false;
  bool _ready = false;
  String? _error;
  Timer? _saveDebounce;
  ReaderSettings? _appliedSettings;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel('Tap', onMessageReceived: _onJsTap)
      ..addJavaScriptChannel('Page', onMessageReceived: _onJsPage)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _ready = true);
        },
      ));
    _applyWakelock();
    _loadEpub();
  }

  void _applyWakelock() {
    final keepOn = ref.read(readerSettingsProvider).keepScreenOn;
    if (keepOn != _wakeEnabled) {
      _wakeEnabled = keepOn;
      WakelockPlus.toggle(enable: keepOn);
    }
  }

  Future<void> _loadEpub() async {
    try {
      final bytes = await File(widget.book.filePath).readAsBytes();
      final book = await epubx.EpubReader.readBook(bytes);
      final chapters = _flattenChapters(book.Chapters ?? const []);
      if (chapters.isEmpty) {
        setState(() => _error = 'EPUB has no readable chapters.');
        return;
      }
      final stored = widget.book.position;
      final initialChapter =
          ((stored?['chapter'] as int?) ?? 0).clamp(0, chapters.length - 1);
      final initialPage = (stored?['page'] as int?) ?? 0;
      _chapters = chapters;
      _chapterIndex = initialChapter;
      _pageInChapter = initialPage;
      await _renderCurrentChapter(initialPage: initialPage);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(readerControlsProvider.notifier).state = ReaderControls(
          goPrev: _goPrev,
          goNext: _goNext,
        );
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not open EPUB: $e');
    }
  }

  List<epubx.EpubChapter> _flattenChapters(List<epubx.EpubChapter> input) {
    final out = <epubx.EpubChapter>[];
    for (final c in input) {
      out.add(c);
      final subs = c.SubChapters;
      if (subs != null && subs.isNotEmpty) {
        out.addAll(_flattenChapters(subs));
      }
    }
    return out;
  }

  Future<void> _renderCurrentChapter({required int initialPage}) async {
    final settings = ref.read(readerSettingsProvider);
    _appliedSettings = settings;
    final chapter = _chapters[_chapterIndex];
    final html = _buildHtml(chapter.HtmlContent ?? '', settings, initialPage);
    setState(() => _ready = false);
    await _web.loadHtmlString(html);
  }

  String _buildHtml(String chapterHtml, ReaderSettings s, int initialPage) {
    final fg = _hex(s.theme.foreground);
    final bg = _hex(s.theme.background);
    final padding = s.horizontalPadding;
    final body = _sanitize(chapterHtml);

    final gap = padding * 2;
    return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
  * { box-sizing: border-box; }
  html, body {
    margin: 0;
    padding: 0;
    width: 100vw;
    height: 100vh;
    overflow: hidden;
    background: $bg;
    color: $fg;
  }
  body {
    /* Padding sets the left margin of page 1 and the right margin of the
       last page; column-gap (= 2 * padding) renders as the right margin of
       page N + the left margin of page N+1. column-width is sized so that
       column-width + column-gap == 100vw, keeping scroll-unit aligned to
       window.innerWidth and preventing per-page drift. */
    padding: 56px ${padding}px 24px;
    font-family: '${s.fontFamily}', Georgia, serif;
    font-size: ${s.fontSize}px;
    line-height: ${s.lineHeight};
    column-width: calc(100vw - ${gap}px);
    column-gap: ${gap}px;
    column-fill: auto;
    -webkit-user-select: none;
    user-select: none;
  }
  body::-webkit-scrollbar { display: none; }
  img, svg { max-width: 100%; max-height: 80vh; height: auto; display: block; margin: 1em auto; }
  h1, h2, h3, h4 { break-after: avoid-column; }
  p { margin: 0 0 1em 0; orphans: 2; widows: 2; text-align: justify; }
  a { color: inherit; text-decoration: underline; }
  pre, code { white-space: pre-wrap; word-wrap: break-word; }
  blockquote { margin: 1em 1.5em; font-style: italic; }
</style>
</head>
<body>
$body
<script>
  function w() { return window.innerWidth; }
  function totalPages() {
    return Math.max(1, Math.ceil(document.body.scrollWidth / w()));
  }
  function curPage() {
    var s = document.scrollingElement || document.documentElement;
    return Math.round((s.scrollLeft || document.body.scrollLeft) / w());
  }
  function gotoPage(p) {
    var t = Math.max(0, Math.min(totalPages() - 1, p));
    var x = t * w();
    var s = document.scrollingElement || document.documentElement;
    s.scrollLeft = x;
    document.body.scrollLeft = x;
    return curPage();
  }
  function reportPage() {
    Page.postMessage(JSON.stringify({page: curPage(), total: totalPages()}));
  }
  document.addEventListener('click', function(e) {
    var x = e.clientX, ww = w();
    if (x < ww * 0.3) Tap.postMessage('prev');
    else if (x > ww * 0.7) Tap.postMessage('next');
    else Tap.postMessage('menu');
  }, { passive: true });
  window.addEventListener('load', function() {
    setTimeout(function() { gotoPage($initialPage); reportPage(); }, 80);
  });
</script>
</body>
</html>
''';
  }

  String _hex(Color c) {
    final v = c.toARGB32() & 0xFFFFFF;
    return '#${v.toRadixString(16).padLeft(6, '0')}';
  }

  String _sanitize(String html) {
    return html
        .replaceAll(RegExp(r'<\?xml[^>]*\?>'), '')
        .replaceAll(RegExp(r'<!DOCTYPE[^>]*>', caseSensitive: false), '');
  }

  void _onJsTap(JavaScriptMessage msg) {
    switch (msg.message) {
      case 'prev':
        _goPrev();
        break;
      case 'next':
        _goNext();
        break;
      case 'menu':
        widget.onMenuTap();
        break;
    }
  }

  void _onJsPage(JavaScriptMessage msg) {
    try {
      final data = jsonDecode(msg.message) as Map<String, dynamic>;
      _pageInChapter = (data['page'] as num).toInt();
      _pagesInChapter = (data['total'] as num).toInt();
      _saveProgress();
    } catch (_) {}
  }

  void _saveProgress() {
    if (_chapters.isEmpty) return;
    final perChapter = 1.0 / _chapters.length;
    final overall = ((_chapterIndex * perChapter) +
            perChapter * (_pageInChapter / _pagesInChapter.clamp(1, 99999)))
        .clamp(0.0, 1.0);

    ref.read(readerProgressProvider.notifier).state = ReaderProgress(
      fraction: overall,
      label: 'Ch ${_chapterIndex + 1}/${_chapters.length} '
          '· p ${_pageInChapter + 1}/$_pagesInChapter',
    );

    if (widget.book.id == null) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(bookRepositoryProvider).updateProgress(
        widget.book.id!,
        progress: overall,
        position: {'chapter': _chapterIndex, 'page': _pageInChapter},
      );
    });
  }

  Future<void> _goPrev() async {
    if (!_ready) return;
    if (_pageInChapter > 0) {
      await _web.runJavaScript('gotoPage(curPage() - 1); reportPage();');
    } else if (_chapterIndex > 0) {
      _chapterIndex--;
      await _renderCurrentChapter(initialPage: 99999);
    }
  }

  Future<void> _goNext() async {
    if (!_ready) return;
    if (_pageInChapter < _pagesInChapter - 1) {
      await _web.runJavaScript('gotoPage(curPage() + 1); reportPage();');
    } else if (_chapterIndex < _chapters.length - 1) {
      _chapterIndex++;
      await _renderCurrentChapter(initialPage: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    _applyWakelock();

    if (_appliedSettings != null && settings != _appliedSettings) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _chapters.isNotEmpty) {
          _renderCurrentChapter(initialPage: _pageInChapter);
        }
      });
    }

    if (_error != null) {
      return Container(
        color: settings.theme.background,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(32),
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: TextStyle(color: settings.theme.foreground),
        ),
      );
    }

    if (_chapters.isEmpty) {
      return Container(
        color: settings.theme.background,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    return Container(
      color: settings.theme.background,
      child: WebViewWidget(controller: _web),
    );
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    if (_wakeEnabled) WakelockPlus.disable();
    super.dispose();
  }
}
