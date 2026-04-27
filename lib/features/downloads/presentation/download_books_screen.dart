import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../shared/navigation/main_drawer.dart';
import '../../library/providers/library_provider.dart';
import '../services/book_download_service.dart';

const _startUrl = 'https://fr.annas-archive.gl/';
const _supportedExtensions = ['epub', 'pdf', 'azw', 'azw3', 'mobi'];

class DownloadBooksScreen extends ConsumerStatefulWidget {
  const DownloadBooksScreen({super.key});

  @override
  ConsumerState<DownloadBooksScreen> createState() =>
      _DownloadBooksScreenState();
}

class _DownloadBooksScreenState extends ConsumerState<DownloadBooksScreen> {
  InAppWebViewController? _controller;
  final _downloadService = BookDownloadService();
  bool _downloading = false;

  Future<void> _onDownloadStart(
    InAppWebViewController controller,
    DownloadStartRequest request,
  ) async {
    final url = request.url;
    final filename = _filenameFor(request);
    final ext = p
        .extension(filename)
        .replaceAll('.', '')
        .toLowerCase();
    if (!_supportedExtensions.contains(ext)) {
      // Per user preference: silently ignore unsupported formats.
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _downloading = true);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(minutes: 5),
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Downloading $filename…')),
          ],
        ),
      ),
    );

    String? currentUrl;
    try {
      currentUrl = (await controller.getUrl())?.toString();
    } catch (_) {}

    String? userAgent;
    try {
      userAgent = await controller.evaluateJavascript(
        source: 'navigator.userAgent',
      ) as String?;
    } catch (_) {}

    try {
      final result = await _downloadService.downloadToLibrary(
        url: url,
        filename: filename,
        referer: currentUrl,
        userAgent: userAgent,
      );
      final added = await ref
          .read(libraryProvider.notifier)
          .addFromFile(result.savedPath);
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            added
                ? 'Saved $filename to library (${_fmtBytes(result.bytes)})'
                : 'Downloaded $filename — already in library',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  String _filenameFor(DownloadStartRequest request) {
    // Prefer Content-Disposition's `filename=...` attribute when the
    // server provides one. Otherwise fall back to the URL's basename.
    final disp = request.contentDisposition;
    if (disp != null && disp.isNotEmpty) {
      final m = RegExp(
        r'filename\*?=(?:UTF-8)?\s*''?"?([^";]+)"?',
        caseSensitive: false,
      ).firstMatch(disp);
      if (m != null) {
        final raw = m.group(1)!.trim();
        try {
          return Uri.decodeComponent(raw);
        } catch (_) {
          return raw;
        }
      }
    }
    var fromUrl = request.url.pathSegments.isNotEmpty
        ? request.url.pathSegments.last
        : 'book';
    try {
      fromUrl = Uri.decodeComponent(fromUrl);
    } catch (_) {}
    return fromUrl.isEmpty ? 'book' : fromUrl;
  }

  String _fmtBytes(int n) {
    if (n < 1024) return '$n B';
    if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(0)} KB';
    return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _signOut() async {
    await CookieManager.instance().deleteAllCookies();
    await _controller?.loadUrl(
      urlRequest: URLRequest(url: WebUri(_startUrl)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signed out (cookies cleared).')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const MainDrawer(currentRoute: '/downloads'),
      appBar: AppBar(
        title: const Text('Download books'),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            tooltip: 'Back',
            onPressed: () async {
              if (await _controller?.canGoBack() ?? false) {
                _controller?.goBack();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: () => _controller?.reload(),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'home') {
                _controller?.loadUrl(
                  urlRequest: URLRequest(url: WebUri(_startUrl)),
                );
              } else if (v == 'sign_out') {
                _signOut();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'home', child: Text('Go to home')),
              PopupMenuItem(value: 'sign_out', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_downloading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_startUrl)),
              initialSettings: InAppWebViewSettings(
                useOnDownloadStart: true,
                javaScriptEnabled: true,
                javaScriptCanOpenWindowsAutomatically: true,
                supportMultipleWindows: false,
                allowsBackForwardNavigationGestures: true,
                mediaPlaybackRequiresUserGesture: true,
                useHybridComposition: true,
              ),
              onWebViewCreated: (c) => _controller = c,
              onDownloadStartRequest: _onDownloadStart,
            ),
          ),
        ],
      ),
    );
  }
}
