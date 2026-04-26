import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../library/domain/book.dart';
import '../providers/reader_settings_provider.dart';

class AzwReaderView extends ConsumerWidget {
  const AzwReaderView({super.key, required this.book});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final fg = settings.theme.foreground;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 64, color: fg),
            const SizedBox(height: 16),
            Text(
              'Could not convert this Kindle file',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'The kindle_unpack converter rejected this file. It\'s most '
              'likely DRM-protected (a purchase from the Kindle store), '
              'or a Topaz / Print-Replica book. Try removing it and '
              're-importing a non-DRM AZW3 / MOBI instead.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: fg.withValues(alpha: 0.75)),
            ),
          ],
        ),
      ),
    );
  }
}
