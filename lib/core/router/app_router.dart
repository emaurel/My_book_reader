import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../build_flags.dart';

import '../../features/characters/presentation/characters_screen.dart';
import '../../features/citations/presentation/citations_screen.dart';
import '../../features/backup/presentation/backup_screen.dart';
import '../../features/book_links/presentation/links_screen.dart';
import '../../features/bundles/presentation/import_bundle_screen.dart';
import '../../features/dictionary/presentation/dictionaries_screen.dart';
import '../../features/downloads/presentation/download_books_screen.dart';
import '../../features/notes/presentation/notes_screen.dart';
import '../../features/stats/presentation/stats_screen.dart';
import '../../features/settings/presentation/selection_menu_settings_screen.dart';
import '../../features/library/presentation/current_readings_screen.dart';
import '../../features/library/presentation/library_screen.dart';
import '../../features/reader/presentation/reader_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'library',
        builder: (_, __) => const LibraryScreen(),
      ),
      GoRoute(
        path: '/current',
        name: 'current_readings',
        builder: (_, __) => const CurrentReadingsScreen(),
      ),
      GoRoute(
        path: '/read/:id',
        name: 'reader',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          final citationId =
              int.tryParse(state.uri.queryParameters['citation'] ?? '');
          return ReaderScreen(bookId: id, citationId: citationId);
        },
      ),
      GoRoute(
        path: '/citations',
        name: 'citations',
        builder: (_, __) => const CitationsScreen(),
      ),
      GoRoute(
        path: '/dictionaries',
        name: 'dictionaries',
        builder: (_, __) => const DictionariesScreen(),
      ),
      GoRoute(
        path: '/characters',
        name: 'characters',
        builder: (_, __) => const CharactersScreen(),
      ),
      GoRoute(
        path: '/links',
        name: 'links',
        builder: (_, __) => const LinksScreen(),
      ),
      GoRoute(
        path: '/notes',
        name: 'notes',
        builder: (_, __) => const NotesScreen(),
      ),
      GoRoute(
        path: '/stats',
        name: 'stats',
        builder: (_, __) => const StatsScreen(),
      ),
      if (!kStoreBuild)
        GoRoute(
          path: '/downloads',
          name: 'downloads',
          builder: (_, __) => const DownloadBooksScreen(),
        ),
      GoRoute(
        path: '/backup',
        name: 'backup',
        builder: (_, __) => const BackupScreen(),
      ),
      GoRoute(
        path: '/import-bundle',
        name: 'import_bundle',
        builder: (_, __) => const ImportBundleScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/selection-menu',
        name: 'selection_menu_settings',
        builder: (_, __) => const SelectionMenuSettingsScreen(),
      ),
    ],
  );
});
