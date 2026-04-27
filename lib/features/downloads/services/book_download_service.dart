import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DownloadResult {
  DownloadResult({required this.savedPath, required this.bytes});
  final String savedPath;
  final int bytes;
}

class BookDownloadService {
  /// Fetch [url] using the WebView's cookie jar (so Cloudflare /
  /// membership-gated redirects work) and save the bytes to the app's
  /// `library/` directory under [filename] (made unique if needed).
  Future<DownloadResult> downloadToLibrary({
    required Uri url,
    required String filename,
    String? referer,
    String? userAgent,
  }) async {
    final cookieHeader = await _cookieHeaderFor(url);

    final response = await http.get(
      url,
      headers: {
        if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
        if (userAgent != null) 'User-Agent': userAgent,
        if (referer != null) 'Referer': referer,
        'Accept': '*/*',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Download failed: HTTP ${response.statusCode}',
        uri: url,
      );
    }
    if (response.bodyBytes.isEmpty) {
      throw HttpException('Download returned empty body', uri: url);
    }

    final dir = await _libraryDir();
    final destPath = await _uniquePath(dir, filename);
    await File(destPath).writeAsBytes(response.bodyBytes, flush: true);

    return DownloadResult(
      savedPath: destPath,
      bytes: response.bodyBytes.length,
    );
  }

  Future<String> _cookieHeaderFor(Uri url) async {
    final manager = CookieManager.instance();
    final cookies = await manager.getCookies(url: WebUri.uri(url));
    return cookies
        .where((c) => c.value != null)
        .map((c) => '${c.name}=${c.value}')
        .join('; ');
  }

  Future<Directory> _libraryDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'library'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> _uniquePath(Directory dir, String filename) async {
    // Strip any path separators from the filename to defend against
    // server-supplied Content-Disposition with traversal characters.
    final safe = filename.replaceAll(RegExp(r'[/\\]'), '_');
    final base = p.basenameWithoutExtension(safe);
    final ext = p.extension(safe);
    var candidate = p.join(dir.path, safe);
    var counter = 1;
    while (await File(candidate).exists()) {
      candidate = p.join(dir.path, '$base ($counter)$ext');
      counter++;
    }
    return candidate;
  }
}
