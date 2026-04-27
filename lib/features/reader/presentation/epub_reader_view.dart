import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:epubx/epubx.dart' as epubx;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../characters/presentation/widgets/character_descriptions_sheet.dart';
import '../../characters/providers/character_provider.dart';
import '../../citations/providers/citation_provider.dart';
import '../../dictionary/presentation/widgets/definition_sheet.dart';
import '../../dictionary/providers/dictionary_provider.dart';
import '../../library/domain/book.dart';
import '../../library/providers/library_provider.dart';
import '../providers/reader_controls_provider.dart';
import '../providers/reader_progress_provider.dart';
import '../providers/reader_settings_provider.dart';
import '../selection/selection_action.dart';
import '../selection/selection_actions_provider.dart';

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
    this.previewMode = false,
    this.previewCitationId,
  });

  final Book book;
  final VoidCallback onMenuTap;

  /// When true, the viewer reads but doesn't write — progress and
  /// position are not persisted. Used when previewing a citation from
  /// the citations list so it doesn't disturb the user's saved spot.
  final bool previewMode;

  /// If set, after the chapter loads we scroll to the page containing
  /// this citation's highlight.
  final int? previewCitationId;

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
  _Selection? _selection;
  _TappedCitation? _tappedCitation;
  Map<String, epubx.EpubByteContentFile> _images = const {};

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel('Tap', onMessageReceived: _onJsTap)
      ..addJavaScriptChannel('Page', onMessageReceived: _onJsPage)
      ..addJavaScriptChannel('Selection', onMessageReceived: _onJsSelection)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) async {
          if (!mounted) return;
          setState(() => _ready = true);
          await _refreshAllHighlights();
          // Everything is now in its final position. Reveal the body so
          // chapter transitions don't flash page 0 first.
          await _web.runJavaScript('revealBody();');
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
      _images = book.Content?.Images ?? const {};
      await _renderCurrentChapter(initialPage: initialPage);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _publishControls();
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not open EPUB: $e');
    }
  }

  void _publishControls() {
    ref.read(readerControlsProvider.notifier).state = ReaderControls(
      goPrev: _goPrev,
      goNext: _goNext,
      jumpToChapter: _jumpToChapter,
      chapterTitles: [
        for (final c in _chapters) _bestChapterTitle(c),
      ],
      currentChapterIndex: _chapterIndex,
    );
  }

  /// Resolve a usable display title for a chapter. The NCX label is
  /// preferred unless it's generic (e.g. "Part 1" — what kindle_unpack
  /// emits when the source AZW3 didn't carry an explicit title), in
  /// which case we fall back to the first heading in the chapter HTML.
  String _bestChapterTitle(epubx.EpubChapter c) {
    final navTitle = (c.Title ?? '').trim();
    final navIsGeneric = _isGenericChapterLabel(navTitle);
    if (navTitle.isNotEmpty && !navIsGeneric) return navTitle;
    final fromHtml = _firstHeadingText(c.HtmlContent ?? '');
    if (fromHtml != null && fromHtml.isNotEmpty) return fromHtml;
    return navTitle.isEmpty ? 'Untitled' : navTitle;
  }

  static final _genericLabel = RegExp(
    r'^(part|chapter|section|ch)\s*[ivxlcdm0-9]+\s*\.?$',
    caseSensitive: false,
  );

  bool _isGenericChapterLabel(String s) =>
      s.isEmpty || _genericLabel.hasMatch(s);

  static final _headingRe = RegExp(
    r'<h[1-3][^>]*>([\s\S]*?)</h[1-3]>',
    caseSensitive: false,
  );
  static final _tagStripRe = RegExp(r'<[^>]+>');
  static final _wsRe = RegExp(r'\s+');

  String? _firstHeadingText(String html) {
    final m = _headingRe.firstMatch(html);
    if (m == null) return null;
    var text = m.group(1) ?? '';
    text = text.replaceAll(_tagStripRe, ' ');
    text = _decodeEntities(text);
    text = text.replaceAll(_wsRe, ' ').trim();
    if (text.isEmpty) return null;
    // Don't fall through to a heading that's itself generic.
    if (_isGenericChapterLabel(text)) return null;
    return text;
  }

  String _decodeEntities(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&#8217;', '’')
      .replaceAll('&#8216;', '‘');

  Future<void> _jumpToChapter(int index) async {
    if (index < 0 || index >= _chapters.length) return;
    if (index == _chapterIndex) return;
    _chapterIndex = index;
    await _renderCurrentChapter(initialPage: 0);
    _publishControls();
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
    final body = _inlineImages(_sanitize(chapterHtml));

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
    visibility: hidden; /* revealed by JS once initial page is positioned */
    padding: 56px ${padding}px 24px;
    font-family: '${s.fontFamily}', Georgia, serif;
    font-size: ${s.fontSize}px;
    line-height: ${s.lineHeight};
    column-width: calc(100vw - ${gap}px);
    column-gap: ${gap}px;
    column-fill: auto;
    /* Disable native selection so Android's ActionMode (Copy/Share)
       never appears; we implement our own single-word selection in JS. */
    -webkit-user-select: none;
    user-select: none;
    -webkit-touch-callout: none;
  }
  body::-webkit-scrollbar { display: none; }
  /* Highlight applied by our custom in-progress selection. */
  .cu-sel {
    background: rgba(255, 200, 0, 0.4);
    border-radius: 2px;
  }
  /* Persistent citation highlight (saved). Subtler than cu-sel. */
  .cu-cite {
    background: rgba(255, 200, 0, 0.22);
    border-bottom: 1.5px solid rgba(220, 150, 0, 0.7);
    border-radius: 2px;
    cursor: pointer;
  }
  /* Dictionary word — dotted underline, no background, distinguishable
     from citation's solid underline. */
  .cu-dict {
    border-bottom: 1.5px dotted rgba(80, 130, 220, 0.85);
    cursor: pointer;
  }
  /* Character name — dashed underline in green so it's visually distinct
     from cu-dict (dotted blue) and cu-cite (solid amber). */
  .cu-char {
    border-bottom: 1.5px dashed rgba(60, 160, 100, 0.9);
    cursor: pointer;
  }
  /* Outer hitbox is 44px (Material minimum touch target). The visible
     dot is drawn via ::before so the larger transparent area absorbs
     touches without making the marker huge. */
  .cu-handle {
    position: fixed;
    width: 44px;
    height: 44px;
    margin-left: -22px;
    margin-top: -4px;
    background: transparent;
    z-index: 9999;
    pointer-events: auto;
    display: none;
    -webkit-user-select: none;
    user-select: none;
    touch-action: none;
  }
  .cu-handle::before {
    content: '';
    position: absolute;
    top: 4px;
    left: 13px;
    width: 18px;
    height: 18px;
    background: rgba(255, 170, 0, 0.95);
    border-radius: 50%;
    border: 2px solid white;
    box-shadow: 0 1px 4px rgba(0, 0, 0, 0.3);
  }
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
  function _scrollTarget() {
    return document.scrollingElement || document.documentElement;
  }

  function _setScrollLeftInstant(x) {
    if (_animFrame) { cancelAnimationFrame(_animFrame); _animFrame = null; }
    var s = _scrollTarget();
    s.scrollLeft = x;
    document.body.scrollLeft = x;
  }

  // Page-flip animation: snap scrollLeft to the new page instantly,
  // then animate body's translateX from the old offset back to 0. This
  // makes the body literally slide on screen — forward = leftwards,
  // backward = rightwards — so the direction is visually unmistakable.
  var _animFrame = null;
  var ANIM_MS = 120;

  function gotoPage(p, animate) {
    if (typeof clearActiveSelection === 'function') clearActiveSelection();
    var t = Math.max(0, Math.min(totalPages() - 1, p));
    var x = t * w();
    var s = _scrollTarget();
    var oldX = s.scrollLeft || document.body.scrollLeft || 0;
    var dx = x - oldX;

    if (animate === false || dx === 0) {
      _setScrollLeftInstant(x);
      reportPage();
      return t;
    }

    if (_animFrame) { cancelAnimationFrame(_animFrame); _animFrame = null; }

    // Snap to the destination, then offset the body so it visually
    // starts where it was and animate the offset back to 0.
    s.scrollLeft = x;
    document.body.scrollLeft = x;

    var startTime = performance.now();
    function step(now) {
      var pp = Math.min(1, (now - startTime) / ANIM_MS);
      var ease = 1 - Math.pow(1 - pp, 3); // ease-out cubic
      var tx = dx * (1 - ease);
      document.body.style.transform = 'translateX(' + tx + 'px)';
      if (pp < 1) {
        _animFrame = requestAnimationFrame(step);
      } else {
        _animFrame = null;
        document.body.style.transform = '';
        reportPage();
      }
    }
    _animFrame = requestAnimationFrame(step);
    return t;
  }
  function reportPage() {
    Page.postMessage(JSON.stringify({page: curPage(), total: totalPages()}));
  }
  // ===== Custom phrase selection (Android ActionMode bypass) =====
  // Selection is tracked as two absolute character offsets within
  // <body>. That's stable across DOM mutations (span wrap/unwrap don't
  // change total text length), so we can re-derive the live Range from
  // those numbers on every operation.
  var LONG_PRESS_MS = 450;
  var MOVE_TOLERANCE_PX = 10;
  var selStart = null;
  var selEnd = null;
  var activeSpans = [];
  var handleStart = null;
  var handleEnd = null;
  var draggingHandle = null;
  var pressStart = null;
  var longPressTimer = null;
  var dragRaf = null;
  var pendingDrag = null;
  var suppressNextClick = false;

  function isTextNode(n) { return n && n.nodeType === Node.TEXT_NODE; }

  // Walk text nodes (skipping our own selection spans only matters
  // because we want consistent offsets — including spans is fine since
  // they don't add characters). Returns {node, offset} for an absolute
  // body-level character position.
  function nodeAtOffset(abs) {
    if (abs < 0) return null;
    var iter = document.createNodeIterator(document.body, NodeFilter.SHOW_TEXT);
    var total = 0;
    var n;
    while ((n = iter.nextNode())) {
      var len = n.textContent.length;
      if (total + len >= abs) {
        return {node: n, offset: abs - total};
      }
      total += len;
    }
    return null;
  }

  function absoluteOffset(node, offset) {
    var iter = document.createNodeIterator(document.body, NodeFilter.SHOW_TEXT);
    var total = 0;
    var n;
    while ((n = iter.nextNode())) {
      if (n === node) return total + offset;
      total += n.textContent.length;
    }
    return -1;
  }

  function unwrapActive() {
    for (var i = 0; i < activeSpans.length; i++) {
      var span = activeSpans[i];
      var parent = span.parentNode;
      if (!parent) continue;
      while (span.firstChild) parent.insertBefore(span.firstChild, span);
      parent.removeChild(span);
    }
    activeSpans = [];
    document.body.normalize();
  }

  function wrapAbs(start, end) {
    if (start === null || end === null || start >= end) return [];
    var s = nodeAtOffset(start);
    var e = nodeAtOffset(end);
    if (!s || !e) return [];
    var range = document.createRange();
    try { range.setStart(s.node, s.offset); range.setEnd(e.node, e.offset); }
    catch (_) { return []; }
    // Collect text fragments in document order.
    var fragments = [];
    var iter = document.createNodeIterator(
      range.commonAncestorContainer,
      NodeFilter.SHOW_TEXT,
      function(node) {
        return range.intersectsNode(node)
          ? NodeFilter.FILTER_ACCEPT
          : NodeFilter.FILTER_REJECT;
      }
    );
    var node;
    while ((node = iter.nextNode())) {
      var fStart = (node === range.startContainer) ? range.startOffset : 0;
      var fEnd = (node === range.endContainer)
        ? range.endOffset : node.textContent.length;
      if (fStart < fEnd) fragments.push({node: node, start: fStart, end: fEnd});
    }
    var spans = [];
    // Wrap in reverse so DOM mutations don't shift later fragment refs.
    for (var i = fragments.length - 1; i >= 0; i--) {
      var f = fragments[i];
      var sub = document.createRange();
      try { sub.setStart(f.node, f.start); sub.setEnd(f.node, f.end); }
      catch (_) { continue; }
      var span = document.createElement('span');
      span.className = 'cu-sel';
      try { sub.surroundContents(span); spans.unshift(span); }
      catch (_) {}
    }
    return spans;
  }

  function setSelection(start, end) {
    if (start === null || end === null) {
      unwrapActive();
      selStart = selEnd = null;
      reportSelection();
      return;
    }
    if (start > end) { var t = start; start = end; end = t; }
    if (start === end) {
      unwrapActive();
      selStart = selEnd = null;
      reportSelection();
      return;
    }
    unwrapActive();
    activeSpans = wrapAbs(start, end);
    if (activeSpans.length === 0) {
      selStart = selEnd = null;
      reportSelection();
      return;
    }
    selStart = start;
    selEnd = end;
    reportSelection();
  }

  function selectedText() {
    var s = '';
    for (var i = 0; i < activeSpans.length; i++) s += activeSpans[i].textContent;
    return s;
  }

  // First and last *line* rects, by combining per-line client rects of
  // every span. This makes handles correctly land on the start of the
  // first line and the end of the last line, even across paragraphs.
  function firstAndLastLineRects() {
    if (activeSpans.length === 0) return null;
    var firstRects = activeSpans[0].getClientRects();
    var lastRects = activeSpans[activeSpans.length - 1].getClientRects();
    if (firstRects.length === 0 || lastRects.length === 0) return null;
    return {
      first: firstRects[0],
      last: lastRects[lastRects.length - 1],
    };
  }

  function selectionBoundingRect() {
    if (activeSpans.length === 0) return null;
    var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    for (var i = 0; i < activeSpans.length; i++) {
      var rs = activeSpans[i].getClientRects();
      for (var j = 0; j < rs.length; j++) {
        var r = rs[j];
        if (r.left < minX) minX = r.left;
        if (r.top < minY) minY = r.top;
        if (r.right > maxX) maxX = r.right;
        if (r.bottom > maxY) maxY = r.bottom;
      }
    }
    if (minX === Infinity) return null;
    return {left: minX, top: minY, width: maxX - minX, height: maxY - minY};
  }

  function ensureHandles() {
    if (!handleStart) {
      handleStart = document.createElement('div');
      handleStart.className = 'cu-handle';
      handleStart.dataset.role = 'start';
      attachHandleEvents(handleStart);
      document.body.appendChild(handleStart);
    }
    if (!handleEnd) {
      handleEnd = document.createElement('div');
      handleEnd.className = 'cu-handle';
      handleEnd.dataset.role = 'end';
      attachHandleEvents(handleEnd);
      document.body.appendChild(handleEnd);
    }
  }

  function hideHandles() {
    if (handleStart) handleStart.style.display = 'none';
    if (handleEnd) handleEnd.style.display = 'none';
  }

  function positionHandles() {
    if (activeSpans.length === 0) { hideHandles(); return; }
    var lr = firstAndLastLineRects();
    if (!lr) { hideHandles(); return; }
    ensureHandles();
    handleStart.style.display = 'block';
    handleStart.style.left = lr.first.left + 'px';
    handleStart.style.top = lr.first.bottom + 'px';
    handleEnd.style.display = 'block';
    handleEnd.style.left = lr.last.right + 'px';
    handleEnd.style.top = lr.last.bottom + 'px';
  }

  function reportSelection() {
    if (selStart === null || activeSpans.length === 0) {
      Selection.postMessage(JSON.stringify({type: 'cleared'}));
      hideHandles();
      return;
    }
    var rect = selectionBoundingRect();
    if (!rect) {
      Selection.postMessage(JSON.stringify({type: 'cleared'}));
      hideHandles();
      return;
    }
    Selection.postMessage(JSON.stringify({
      type: 'changed',
      text: selectedText(),
      start: selStart,
      end: selEnd,
      x: rect.left, y: rect.top,
      width: rect.width, height: rect.height,
    }));
    positionHandles();
  }

  // ===== Persistent citation highlights =====
  function unwrapAllCitations() {
    var spans = document.querySelectorAll('span.cu-cite');
    for (var i = 0; i < spans.length; i++) {
      var span = spans[i];
      var parent = span.parentNode;
      if (!parent) continue;
      while (span.firstChild) parent.insertBefore(span.firstChild, span);
      parent.removeChild(span);
    }
    document.body.normalize();
  }

  function wrapCitation(id, start, end) {
    if (start == null || end == null || start >= end) return;
    var s = nodeAtOffset(start);
    var e = nodeAtOffset(end);
    if (!s || !e) return;
    var range = document.createRange();
    try { range.setStart(s.node, s.offset); range.setEnd(e.node, e.offset); }
    catch (_) { return; }
    var fragments = [];
    var iter = document.createNodeIterator(
      range.commonAncestorContainer,
      NodeFilter.SHOW_TEXT,
      function(node) {
        return range.intersectsNode(node)
          ? NodeFilter.FILTER_ACCEPT
          : NodeFilter.FILTER_REJECT;
      }
    );
    var node;
    while ((node = iter.nextNode())) {
      var fStart = (node === range.startContainer) ? range.startOffset : 0;
      var fEnd = (node === range.endContainer)
        ? range.endOffset : node.textContent.length;
      if (fStart < fEnd) fragments.push({node: node, start: fStart, end: fEnd});
    }
    for (var i = fragments.length - 1; i >= 0; i--) {
      var f = fragments[i];
      var sub = document.createRange();
      try { sub.setStart(f.node, f.start); sub.setEnd(f.node, f.end); }
      catch (_) { continue; }
      var span = document.createElement('span');
      span.className = 'cu-cite';
      span.setAttribute('data-cite-id', String(id));
      try { sub.surroundContents(span); } catch (_) {}
    }
  }

  window.applyCitationHighlights = function(arr) {
    unwrapAllCitations();
    if (!arr || arr.length === 0) return;
    arr.sort(function(a, b) { return a.start - b.start; });
    for (var i = 0; i < arr.length; i++) {
      wrapCitation(arr[i].id, arr[i].start, arr[i].end);
    }
  };

  window.removeCitationHighlight = function(id) {
    var spans = document.querySelectorAll(
      'span.cu-cite[data-cite-id="' + id + '"]');
    for (var i = 0; i < spans.length; i++) {
      var span = spans[i];
      var parent = span.parentNode;
      if (!parent) continue;
      while (span.firstChild) parent.insertBefore(span.firstChild, span);
      parent.removeChild(span);
    }
    document.body.normalize();
  };

  // ===== Character name underlines =====
  function unwrapAllCharacters() {
    var spans = document.querySelectorAll('span.cu-char');
    for (var i = 0; i < spans.length; i++) {
      var span = spans[i];
      var parent = span.parentNode;
      if (!parent) continue;
      while (span.firstChild) parent.insertBefore(span.firstChild, span);
      parent.removeChild(span);
    }
    document.body.normalize();
  }

  // Payload shape: [{id: 1, names: ['James Holden', 'Holden', 'Jim']}, ...]
  // Multiple names can map to the same character id.
  window.applyCharacterHighlights = function(payload) {
    unwrapAllCharacters();
    if (!payload || payload.length === 0) return;
    var entries = []; // {pattern: 'EscapedName', id: 1}
    for (var i = 0; i < payload.length; i++) {
      var p = payload[i];
      if (!p || !p.id || !p.names) continue;
      for (var j = 0; j < p.names.length; j++) {
        var n = p.names[j];
        if (typeof n !== 'string' || n.length === 0) continue;
        entries.push({pattern: escapeRegex(n), id: p.id});
      }
    }
    if (entries.length === 0) return;
    // Sort by pattern length DESC so longer names match first
    // ("James Holden" > "Holden" > "Jim").
    entries.sort(function(a, b) { return b.pattern.length - a.pattern.length; });
    // Map each pattern back to its character id via the regex match index.
    var alternation = entries.map(function(e) { return e.pattern; }).join('|');
    var re = new RegExp('\\\\b(' + alternation + ')\\\\b', 'gi');
    var idForLowerName = {};
    for (var k = 0; k < entries.length; k++) {
      idForLowerName[
        entries[k].pattern.toLowerCase().replace(/\\\\(.)/g, '\$1')
      ] = entries[k].id;
    }

    function shouldSkipNode(n) {
      var p = n.parentNode;
      while (p && p !== document.body) {
        if (p.nodeType === Node.ELEMENT_NODE && p.classList) {
          if (p.classList.contains('cu-char')) return true;
          if (p.classList.contains('cu-dict')) return true;
          if (p.classList.contains('cu-handle')) return true;
        }
        p = p.parentNode;
      }
      return false;
    }

    var iter = document.createNodeIterator(
      document.body,
      NodeFilter.SHOW_TEXT,
      function(n) { return shouldSkipNode(n)
        ? NodeFilter.FILTER_REJECT
        : NodeFilter.FILTER_ACCEPT; }
    );
    var candidates = [];
    var node;
    while ((node = iter.nextNode())) {
      if (!node.textContent || node.textContent.length === 0) continue;
      candidates.push(node);
    }

    for (var j = 0; j < candidates.length; j++) {
      var n = candidates[j];
      var text = n.textContent;
      re.lastIndex = 0;
      if (!re.test(text)) continue;
      re.lastIndex = 0;
      var frag = document.createDocumentFragment();
      var lastIdx = 0;
      var m;
      while ((m = re.exec(text)) !== null) {
        if (m.index > lastIdx) {
          frag.appendChild(
            document.createTextNode(text.slice(lastIdx, m.index)));
        }
        var span = document.createElement('span');
        span.className = 'cu-char';
        span.setAttribute('data-name', m[0]);
        var charId = idForLowerName[m[0].toLowerCase()];
        if (charId !== undefined) {
          span.setAttribute('data-char-id', String(charId));
        }
        span.textContent = m[0];
        frag.appendChild(span);
        lastIdx = m.index + m[0].length;
      }
      if (lastIdx < text.length) {
        frag.appendChild(document.createTextNode(text.slice(lastIdx)));
      }
      if (n.parentNode) n.parentNode.replaceChild(frag, n);
    }
  };

  // ===== Dictionary word underlines =====
  function unwrapAllDictionary() {
    var spans = document.querySelectorAll('span.cu-dict');
    for (var i = 0; i < spans.length; i++) {
      var span = spans[i];
      var parent = span.parentNode;
      if (!parent) continue;
      while (span.firstChild) parent.insertBefore(span.firstChild, span);
      parent.removeChild(span);
    }
    document.body.normalize();
  }

  function escapeRegex(s) {
    return s.replace(/[\\\\.*+?^\${}()|[\\]\\\\]/g, '\\\\\$&');
  }

  // Wrap every standalone occurrence of any word in `words`. Skips text
  // already inside cu-dict / cu-handle spans to avoid double-wrap and
  // recursion. cu-cite / cu-sel are intentionally allowed — fine for
  // both decorations to coexist.
  window.applyDictionaryHighlights = function(words) {
    unwrapAllDictionary();
    if (!words || words.length === 0) return;
    var escaped = [];
    for (var i = 0; i < words.length; i++) {
      var w = words[i];
      if (typeof w !== 'string' || w.length === 0) continue;
      escaped.push(escapeRegex(w));
    }
    if (escaped.length === 0) return;
    var re = new RegExp('\\\\b(' + escaped.join('|') + ')\\\\b', 'gi');

    function shouldSkipNode(n) {
      var p = n.parentNode;
      while (p && p !== document.body) {
        if (p.nodeType === Node.ELEMENT_NODE && p.classList) {
          if (p.classList.contains('cu-dict')) return true;
          if (p.classList.contains('cu-char')) return true;
          if (p.classList.contains('cu-handle')) return true;
        }
        p = p.parentNode;
      }
      return false;
    }

    // Collect candidate text nodes first; mutating during walk is
    // unsafe.
    var iter = document.createNodeIterator(
      document.body,
      NodeFilter.SHOW_TEXT,
      function(n) { return shouldSkipNode(n)
        ? NodeFilter.FILTER_REJECT
        : NodeFilter.FILTER_ACCEPT; }
    );
    var candidates = [];
    var node;
    while ((node = iter.nextNode())) {
      if (!node.textContent || node.textContent.length === 0) continue;
      candidates.push(node);
    }

    for (var j = 0; j < candidates.length; j++) {
      var n = candidates[j];
      var text = n.textContent;
      re.lastIndex = 0;
      var hasMatch = re.test(text);
      if (!hasMatch) continue;
      // Build a doc fragment with text + cu-dict spans for matches.
      re.lastIndex = 0;
      var frag = document.createDocumentFragment();
      var lastIdx = 0;
      var m;
      while ((m = re.exec(text)) !== null) {
        if (m.index > lastIdx) {
          frag.appendChild(
            document.createTextNode(text.slice(lastIdx, m.index)));
        }
        var span = document.createElement('span');
        span.className = 'cu-dict';
        span.setAttribute('data-word', m[0]);
        span.textContent = m[0];
        frag.appendChild(span);
        lastIdx = m.index + m[0].length;
      }
      if (lastIdx < text.length) {
        frag.appendChild(document.createTextNode(text.slice(lastIdx)));
      }
      if (n.parentNode) n.parentNode.replaceChild(frag, n);
    }
  };

  function clearActiveSelection() {
    unwrapActive();
    selStart = selEnd = null;
    hideHandles();
    Selection.postMessage(JSON.stringify({type: 'cleared'}));
  }

  function highlightWordAt(x, y) {
    unwrapActive();
    selStart = selEnd = null;
    var caret = document.caretRangeFromPoint(x, y);
    if (!caret || !isTextNode(caret.startContainer)) return;
    var node = caret.startContainer;
    var text = node.textContent;
    var offset = caret.startOffset;
    var re = /[\\p{L}\\p{N}_'\\u2019\\-]+/gu;
    var m, wStart = -1, wEnd = -1;
    while ((m = re.exec(text)) !== null) {
      if (offset >= m.index && offset <= m.index + m[0].length) {
        wStart = m.index; wEnd = m.index + m[0].length; break;
      }
    }
    if (wStart < 0) return;
    var absS = absoluteOffset(node, wStart);
    var absE = absoluteOffset(node, wEnd);
    if (absS < 0 || absE < 0) return;
    setSelection(absS, absE);
  }

  function handleDrag(role, clientX, clientY) {
    pendingDrag = {role: role, x: clientX, y: clientY};
    if (dragRaf) return;
    dragRaf = requestAnimationFrame(function() {
      dragRaf = null;
      if (!pendingDrag) return;
      var d = pendingDrag; pendingDrag = null;
      if (selStart === null || selEnd === null) return;
      // Aim slightly above the finger so caret targets the line we see.
      var caret = document.caretRangeFromPoint(d.x, d.y - 22);
      if (!caret || !isTextNode(caret.startContainer)) return;
      var abs = absoluteOffset(caret.startContainer, caret.startOffset);
      if (abs < 0) return;
      if (d.role === 'start') {
        // Drag start handle: change the lower bound.
        var newStart = Math.min(abs, selEnd - 1);
        setSelection(newStart, selEnd);
      } else {
        var newEnd = Math.max(abs, selStart + 1);
        setSelection(selStart, newEnd);
      }
    });
  }

  function attachHandleEvents(el) {
    el.addEventListener('touchstart', function(e) {
      e.stopPropagation();
      e.preventDefault();
      draggingHandle = el.dataset.role;
    }, { passive: false });
    el.addEventListener('touchmove', function(e) {
      e.stopPropagation();
      e.preventDefault();
      if (e.touches.length !== 1 || !draggingHandle) return;
      var t = e.touches[0];
      handleDrag(draggingHandle, t.clientX, t.clientY);
    }, { passive: false });
    el.addEventListener('touchend', function(e) {
      e.stopPropagation();
      e.preventDefault();
      draggingHandle = null;
      reportSelection();
    }, { passive: false });
  }

  // Swipe detection: deltas measured between touchstart and touchend
  // on the body. Disabled while dragging a selection handle or while
  // there's an active selection (so handle drags / tap-to-dismiss don't
  // accidentally turn pages).
  var SWIPE_MIN_X = 50;
  var SWIPE_MAX_DURATION_MS = 600;
  var SWIPE_VERTICAL_RATIO = 0.6;
  var swipeStart = null;

  document.addEventListener('touchstart', function(e) {
    if (draggingHandle || e.touches.length !== 1) return;
    var t = e.touches[0];
    pressStart = {x: t.clientX, y: t.clientY};
    swipeStart = {x: t.clientX, y: t.clientY, time: Date.now()};
    if (longPressTimer) clearTimeout(longPressTimer);
    longPressTimer = setTimeout(function() {
      longPressTimer = null;
      if (!pressStart) return;
      highlightWordAt(pressStart.x, pressStart.y);
      pressStart = null;
      suppressNextClick = true;
    }, LONG_PRESS_MS);
  }, { passive: true });

  document.addEventListener('touchmove', function(e) {
    if (!pressStart || e.touches.length !== 1) return;
    var t = e.touches[0];
    var dx = t.clientX - pressStart.x, dy = t.clientY - pressStart.y;
    if (Math.sqrt(dx * dx + dy * dy) > MOVE_TOLERANCE_PX) {
      if (longPressTimer) { clearTimeout(longPressTimer); longPressTimer = null; }
      pressStart = null;
    }
  }, { passive: true });

  document.addEventListener('touchend', function(e) {
    if (longPressTimer) { clearTimeout(longPressTimer); longPressTimer = null; }
    pressStart = null;
    // Swipe check.
    if (!swipeStart || draggingHandle) { swipeStart = null; return; }
    if (selStart !== null && activeSpans.length > 0) { swipeStart = null; return; }
    if (e.changedTouches.length !== 1) { swipeStart = null; return; }
    var t = e.changedTouches[0];
    var dx = t.clientX - swipeStart.x;
    var dy = t.clientY - swipeStart.y;
    var dt = Date.now() - swipeStart.time;
    swipeStart = null;
    if (dt > SWIPE_MAX_DURATION_MS) return;
    if (Math.abs(dx) < SWIPE_MIN_X) return;
    if (Math.abs(dy) > Math.abs(dx) * SWIPE_VERTICAL_RATIO) return;
    // Real horizontal swipe: navigate, suppress the synthetic click.
    Tap.postMessage(dx < 0 ? 'next' : 'prev');
    suppressNextClick = true;
  }, { passive: true });

  document.addEventListener('click', function(e) {
    if (suppressNextClick) { suppressNextClick = false; return; }
    // Tap on an existing citation or dictionary highlight.
    var t = e.target;
    while (t && t !== document.body) {
      if (t.classList) {
        if (t.classList.contains('cu-cite')) {
          var idAttr = t.getAttribute('data-cite-id');
          var rect = t.getBoundingClientRect();
          Selection.postMessage(JSON.stringify({
            type: 'citation_tap',
            id: parseInt(idAttr, 10),
            x: rect.left, y: rect.top,
            width: rect.width, height: rect.height,
          }));
          return;
        }
        if (t.classList.contains('cu-dict')) {
          var word = t.getAttribute('data-word') || t.textContent;
          Selection.postMessage(JSON.stringify({
            type: 'dict_tap',
            word: word,
          }));
          return;
        }
        if (t.classList.contains('cu-char')) {
          var charName = t.getAttribute('data-name') || t.textContent;
          var charIdAttr = t.getAttribute('data-char-id');
          Selection.postMessage(JSON.stringify({
            type: 'char_tap',
            name: charName,
            id: charIdAttr ? parseInt(charIdAttr, 10) : null,
          }));
          return;
        }
      }
      t = t.parentNode;
    }
    if (selStart !== null && activeSpans.length > 0) {
      var rect2 = selectionBoundingRect();
      var pad = 28; // forgiveness around the selection
      var inside = rect2 &&
        e.clientX >= rect2.left - pad &&
        e.clientX <= rect2.left + rect2.width + pad &&
        e.clientY >= rect2.top - pad &&
        e.clientY <= rect2.top + rect2.height + pad;
      if (!inside) clearActiveSelection();
      return;
    }
    var x = e.clientX, ww = w();
    if (x < ww * 0.3) Tap.postMessage('prev');
    else if (x > ww * 0.7) Tap.postMessage('next');
    else Tap.postMessage('menu');
  }, { passive: true });

  // Exposed for Flutter to clear selection after running an action.
  window.clearActiveSelection = clearActiveSelection;

  // Body starts invisible so chapter changes don't flash page 0 before
  // the real initial page has been positioned. Flutter calls revealBody
  // after gotoPage + applyCitationHighlights have run.
  window.revealBody = function() {
    document.body.style.visibility = 'visible';
  };

  window.addEventListener('load', function() {
    if (typeof gotoPage === 'function') gotoPage($initialPage, false);
    if (typeof reportPage === 'function') reportPage();
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

  /// Replace `<img src="...">` references in chapter HTML with inline
  /// `data:` URIs so the WebView (which can't reach into the EPUB zip)
  /// renders them. Image lookup is by exact key first, then by basename
  /// — paths inside chapter HTML are usually relative to the OPF and
  /// don't always match `Content.Images` keys verbatim.
  static final _imgTagRe = RegExp(r'<img\b[^>]*>', caseSensitive: false);
  static final _srcAttrRe = RegExp(
    "src\\s*=\\s*['\"]([^'\"]+)['\"]",
    caseSensitive: false,
  );

  final Map<String, String> _dataUriCache = {};

  String _inlineImages(String html) {
    if (_images.isEmpty) return html;
    return html.replaceAllMapped(_imgTagRe, (m) {
      final tag = m.group(0)!;
      final src = _srcAttrRe.firstMatch(tag);
      if (src == null) return tag;
      final original = src.group(1)!;
      final dataUri = _dataUriCache.putIfAbsent(
        original,
        () => _toDataUri(original),
      );
      if (dataUri.isEmpty) return tag;
      return tag.replaceFirst(src.group(0)!, 'src="$dataUri"');
    });
  }

  String _toDataUri(String src) {
    // MOBI / KF8 internal scheme: <img src="kindle:embed:0001?mime=...">.
    // kindle_unpack passes these through unchanged, so we resolve them
    // here by looking up the matching `imageNNNNN.<ext>` it emitted.
    final kindle =
        RegExp(r'^kindle:embed:(\d+)', caseSensitive: false).firstMatch(src);
    if (kindle != null) {
      final n = int.tryParse(kindle.group(1) ?? '');
      if (n != null && n >= 0) {
        // Try N-1 then N (1-based vs 0-based ambiguity), each across a
        // few common extensions. Then a positional fallback into the
        // sorted image list.
        for (final offset in [-1, 0]) {
          final idx = n + offset;
          if (idx < 0) continue;
          final base = 'image${idx.toString().padLeft(5, '0')}';
          for (final ext in const ['.jpg', '.jpeg', '.png', '.gif']) {
            final candidate = '$base$ext';
            final found = _findImageByBasename(candidate);
            if (found != null) return _encodeFile(found, candidate);
          }
        }
        final sorted = _images.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        if (n - 1 >= 0 && n - 1 < sorted.length) {
          return _encodeFile(sorted[n - 1].value, sorted[n - 1].key);
        }
      }
      return '';
    }

    final clean = src.split('?').first.split('#').first;
    final basename = clean.split('/').last;
    var found = _images[clean] ?? _images[basename];
    found ??= _findImageByBasename(basename);
    if (found == null) return '';
    return _encodeFile(found, basename);
  }

  epubx.EpubByteContentFile? _findImageByBasename(String basename) {
    final lower = basename.toLowerCase();
    for (final entry in _images.entries) {
      final key = entry.key.toLowerCase();
      if (key.endsWith('/$lower') || key == lower) return entry.value;
    }
    return null;
  }

  String _encodeFile(epubx.EpubByteContentFile file, String hintName) {
    final bytes = file.Content;
    if (bytes == null || bytes.isEmpty) return '';
    final mime = file.ContentMimeType?.isNotEmpty == true
        ? file.ContentMimeType!
        : _mimeFromName(hintName);
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.svg')) return 'image/svg+xml';
    return 'application/octet-stream';
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

  void _onJsSelection(JavaScriptMessage msg) {
    try {
      final data = jsonDecode(msg.message) as Map<String, dynamic>;
      final type = data['type'];

      if (type == 'citation_tap') {
        final id = (data['id'] as num).toInt();
        final rect = Rect.fromLTWH(
          (data['x'] as num).toDouble(),
          (data['y'] as num).toDouble(),
          (data['width'] as num).toDouble(),
          (data['height'] as num).toDouble(),
        );
        setState(() {
          _selection = null;
          _tappedCitation = _TappedCitation(id: id, rect: rect);
        });
        return;
      }

      if (type == 'dict_tap') {
        final word = data['word'] as String;
        // Show the definition sheet directly — no popup needed first.
        _onDictionaryWordTap(word);
        return;
      }

      if (type == 'char_tap') {
        final name = data['name'] as String;
        final id = (data['id'] as num?)?.toInt();
        _onCharacterNameTap(name: name, characterId: id);
        return;
      }

      if (type != 'changed') {
        if (_selection != null || _tappedCitation != null) {
          setState(() {
            _selection = null;
            _tappedCitation = null;
          });
        }
        return;
      }

      final text = (data['text'] as String).trim();
      if (text.isEmpty) {
        if (_selection != null) setState(() => _selection = null);
        return;
      }
      final next = _Selection(
        text: text,
        rect: Rect.fromLTWH(
          (data['x'] as num).toDouble(),
          (data['y'] as num).toDouble(),
          (data['width'] as num).toDouble(),
          (data['height'] as num).toDouble(),
        ),
        charStart: (data['start'] as num?)?.toInt(),
        charEnd: (data['end'] as num?)?.toInt(),
      );
      setState(() {
        _selection = next;
        _tappedCitation = null;
      });
    } catch (_) {}
  }

  Future<void> _refreshAllHighlights() async {
    await _applyCitationsForCurrentChapter();
    await _applyDictionaryHighlightsForCurrentChapter();
    await _applyCharacterHighlightsForCurrentChapter();
  }

  Future<void> _applyDictionaryHighlightsForCurrentChapter() async {
    final words = await ref
        .read(dictionaryRepositoryProvider)
        .wordsForSeries(widget.book.series);
    final js = 'applyDictionaryHighlights(${jsonEncode(words)});';
    await _web.runJavaScript(js);
  }

  Future<void> _applyCharacterHighlightsForCurrentChapter() async {
    final repo = ref.read(characterRepositoryProvider);
    final chars = await repo.listForSeries(widget.book.series);
    final aliasesByChar = await repo.aliasesByCharacter(widget.book.series);
    final payload = chars
        .where((c) => c.id != null)
        .map((c) => {
              'id': c.id,
              'names': [c.name, ...?aliasesByChar[c.id]],
            })
        .toList();
    final js = 'applyCharacterHighlights(${jsonEncode(payload)});';
    await _web.runJavaScript(js);
  }

  Future<void> _applyCitationsForCurrentChapter() async {
    if (widget.book.id == null) return;
    final cites = await ref
        .read(citationRepositoryProvider)
        .getByBookAndChapter(widget.book.id!, _chapterIndex);
    final payload = cites
        .where((c) => c.charStart != null && c.charEnd != null)
        .map((c) => {
              'id': c.id,
              'start': c.charStart,
              'end': c.charEnd,
            })
        .toList();
    await _web.runJavaScript(
      'applyCitationHighlights(${jsonEncode(payload)});',
    );

    // Preview mode: jump to the page that contains this citation's
    // highlight. Done after applyCitationHighlights so the cu-cite span
    // exists in the DOM and we can read its bounding rect.
    if (widget.previewCitationId != null) {
      final id = widget.previewCitationId;
      await _web.runJavaScript('''
(function() {
  function go() {
    var span = document.querySelector(
      'span.cu-cite[data-cite-id="$id"]'
    );
    if (!span) return;
    var rect = span.getBoundingClientRect();
    var sl = (document.scrollingElement || document.documentElement).scrollLeft || 0;
    var ww = window.innerWidth;
    var page = Math.max(0, Math.floor((rect.left + sl) / ww));
    if (typeof gotoPage === 'function') {
      gotoPage(page, false);
      if (typeof reportPage === 'function') reportPage();
    }
  }
  // Two RAF rounds to make sure layout has settled after the wraps.
  requestAnimationFrame(function() {
    requestAnimationFrame(go);
  });
})();
''');
    }
  }

  Future<void> _onSelectionAction(SelectionAction action) async {
    final sel = _selection;
    if (sel == null) return;
    final ctx = SelectionContext(
      text: sel.text,
      bookId: widget.book.id,
      bookSeries: widget.book.series,
      chapterIndex: _chapterIndex,
      charStart: sel.charStart,
      charEnd: sel.charEnd,
    );
    // Clear the in-progress highlight before showing modal sheets so the
    // selection isn't visually competing with the bottom sheet.
    await _web.runJavaScript('clearActiveSelection();');
    setState(() => _selection = null);
    final result = await action.onTap(context, ref, ctx);
    if (!mounted) return;
    await _refreshAllHighlights();
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _onDictionaryWordTap(String word) async {
    await showDefinitionSheet(
      context,
      word: word,
      bookSeries: widget.book.series,
    );
    if (!mounted) return;
    // The user may have edited or deleted entries from the sheet; the
    // revision listener will trigger a refresh, but call directly for
    // immediacy when staying on the same page.
    await _applyDictionaryHighlightsForCurrentChapter();
  }

  Future<void> _onCharacterNameTap({
    required String name,
    int? characterId,
  }) async {
    await showCharacterDescriptionsSheet(
      context,
      name: name,
      characterId: characterId,
      bookSeries: widget.book.series,
    );
    if (!mounted) return;
    await _applyCharacterHighlightsForCurrentChapter();
  }

  Future<void> _onRemoveCitation(int id) async {
    await ref.read(citationsProvider.notifier).remove(id);
    if (!mounted) return;
    await _web.runJavaScript('removeCitationHighlight($id);');
    setState(() => _tappedCitation = null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Citation removed'),
          duration: Duration(seconds: 2),
        ),
      );
    }
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

    if (widget.previewMode || widget.book.id == null) return;
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
      await _web.runJavaScript('gotoPage(curPage() - 1);');
    } else if (_chapterIndex > 0) {
      _chapterIndex--;
      await _renderCurrentChapter(initialPage: 99999);
      _publishControls();
    }
  }

  Future<void> _goNext() async {
    if (!_ready) return;
    if (_pageInChapter < _pagesInChapter - 1) {
      await _web.runJavaScript('gotoPage(curPage() + 1);');
    } else if (_chapterIndex < _chapters.length - 1) {
      _chapterIndex++;
      await _renderCurrentChapter(initialPage: 0);
      _publishControls();
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

    // When the dictionary entries change anywhere in the app, re-paint
    // underlines on the current chapter without rebuilding the WebView.
    ref.listen<int>(dictionaryEntriesRevisionProvider, (prev, next) {
      if (prev != next && _ready) {
        _applyDictionaryHighlightsForCurrentChapter();
      }
    });
    ref.listen<int>(characterRevisionProvider, (prev, next) {
      if (prev != next && _ready) {
        _applyCharacterHighlightsForCurrentChapter();
      }
    });

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
      child: Stack(
        children: [
          WebViewWidget(
            controller: _web,
            // Eagerly claim all touch gestures inside the WebView so the
            // parent GestureDetector in `reader_screen.dart` doesn't
            // intercept long-press / pan / scroll. JS-side handlers
            // already dispatch tap zones (prev / next / menu) and
            // selection events back to Flutter.
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            },
          ),
          if (_selection != null)
            _SelectionPopup(
              selection: _selection!,
              actions: ref.watch(selectionActionsProvider),
              onActionTap: _onSelectionAction,
            ),
          if (_tappedCitation != null)
            _CitationPopup(
              tapped: _tappedCitation!,
              onRemove: () => _onRemoveCitation(_tappedCitation!.id),
              onDismiss: () => setState(() => _tappedCitation = null),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    if (_wakeEnabled) WakelockPlus.disable();
    super.dispose();
  }
}

class _Selection {
  const _Selection({
    required this.text,
    required this.rect,
    this.charStart,
    this.charEnd,
  });

  final String text;

  /// Selection bounding rect in WebView-local logical pixels (matches the
  /// Stack's coord space because the WebView fills the Stack).
  final Rect rect;

  /// Absolute character offsets within the chapter `<body>`. Persisted
  /// alongside the citation so the highlight can be re-drawn later.
  final int? charStart;
  final int? charEnd;
}

class _TappedCitation {
  const _TappedCitation({required this.id, required this.rect});

  final int id;
  final Rect rect;
}

/// Popup that appears above a text selection in the reader. Renders one
/// button per [SelectionAction] in the registry; tapping invokes
/// [onActionTap] which is responsible for clearing the selection.
class _SelectionPopup extends StatelessWidget {
  const _SelectionPopup({
    required this.selection,
    required this.actions,
    required this.onActionTap,
  });

  final _Selection selection;
  final List<SelectionAction> actions;
  final Future<void> Function(SelectionAction action) onActionTap;

  /// Height of one popup row (icon + text + vertical padding).
  static const double _rowHeight = 44;

  /// How much room above the selection we need to comfortably fit the
  /// popup before falling back to placing it below. We allow up to two
  /// wrapped rows.
  static const double _maxExpectedHeight = _rowHeight * 2;

  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    final viewportSize = MediaQuery.sizeOf(context);

    final selCenter = selection.rect.left + selection.rect.width / 2;
    final alignX =
        ((selCenter / viewportSize.width) * 2 - 1).clamp(-1.0, 1.0);

    final popupContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Align(
        alignment: Alignment(alignX, 0),
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          // Wrap so a long row of actions flows onto a second line
          // when it can't fit horizontally on narrow screens.
          child: Wrap(
            children: [
              for (final a in actions)
                InkWell(
                  onTap: () => onActionTap(a),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(a.icon, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          a.label,
                          style:
                              const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    // Place the popup so its *bottom* (when above) or *top* (when
    // below) hugs the selection. That way the popup's height — which
    // doubles when actions wrap to 2 rows — grows away from the
    // selected text instead of into it.
    final preferAbove = selection.rect.top >= _maxExpectedHeight + _gap;
    if (preferAbove) {
      return Positioned(
        left: 0,
        right: 0,
        bottom: viewportSize.height - selection.rect.top + _gap,
        child: popupContent,
      );
    } else {
      return Positioned(
        left: 0,
        right: 0,
        top: selection.rect.bottom + _gap,
        child: popupContent,
      );
    }
  }
}

/// Popup shown when an existing citation highlight is tapped. For now
/// just offers Remove; could grow to include edit / share / etc. later.
class _CitationPopup extends StatelessWidget {
  const _CitationPopup({
    required this.tapped,
    required this.onRemove,
    required this.onDismiss,
  });

  final _TappedCitation tapped;
  final VoidCallback onRemove;
  final VoidCallback onDismiss;

  static const double _menuHeight = 44;
  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    final viewportSize = MediaQuery.sizeOf(context);

    final tapCenter = tapped.rect.left + tapped.rect.width / 2;
    final alignX =
        ((tapCenter / viewportSize.width) * 2 - 1).clamp(-1.0, 1.0);

    final popup = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Align(
        alignment: Alignment(alignX, 0),
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Remove citation',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final preferAbove = tapped.rect.top >= _menuHeight + _gap;
    final positioned = preferAbove
        ? Positioned(
            left: 0,
            right: 0,
            bottom: viewportSize.height - tapped.rect.top + _gap,
            child: popup,
          )
        : Positioned(
            left: 0,
            right: 0,
            top: tapped.rect.bottom + _gap,
            child: popup,
          );

    return Stack(
      children: [
        // Tap-outside-to-dismiss backdrop. Translucent so the page is
        // still visible behind the popup.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
          ),
        ),
        positioned,
      ],
    );
  }
}
