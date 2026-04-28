import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/build_flags.dart';

/// One entry in the app's left drawer. Add new sections by appending to
/// [mainDrawerEntries] below — no code in this file needs to change.
class DrawerEntry {
  const DrawerEntry({
    required this.icon,
    required this.label,
    required this.routePath,
  });

  final IconData icon;
  final String label;
  final String routePath;
}

/// Single source of truth for the drawer contents. Add a new item here
/// and create the matching `GoRoute` in `app_router.dart`.
const List<DrawerEntry> mainDrawerEntries = [
  DrawerEntry(
    icon: Icons.auto_stories_outlined,
    label: 'Continue reading',
    routePath: '/current',
  ),
  DrawerEntry(
    icon: Icons.menu_book_outlined,
    label: 'Library',
    routePath: '/',
  ),
  DrawerEntry(
    icon: Icons.format_quote_outlined,
    label: 'Citations',
    routePath: '/citations',
  ),
  DrawerEntry(
    icon: Icons.menu_book_outlined,
    label: 'Dictionaries',
    routePath: '/dictionaries',
  ),
  DrawerEntry(
    icon: Icons.person_outline,
    label: 'Characters',
    routePath: '/characters',
  ),
  DrawerEntry(
    icon: Icons.link,
    label: 'Links',
    routePath: '/links',
  ),
  DrawerEntry(
    icon: Icons.sticky_note_2_outlined,
    label: 'Notes',
    routePath: '/notes',
  ),
  if (!kStoreBuild)
    DrawerEntry(
      icon: Icons.cloud_download_outlined,
      label: 'Download books',
      routePath: '/downloads',
    ),
  DrawerEntry(
    icon: Icons.backup_outlined,
    label: 'Backup & restore',
    routePath: '/backup',
  ),
  DrawerEntry(
    icon: Icons.unarchive_outlined,
    label: 'Import bundle',
    routePath: '/import-bundle',
  ),
];

/// Footer entries pinned to the bottom of the drawer with a divider
/// separating them from the main navigation. Currently just Settings.
const List<DrawerEntry> drawerFooterEntries = [
  DrawerEntry(
    icon: Icons.settings_outlined,
    label: 'Settings',
    routePath: '/settings',
  ),
];

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key, required this.currentRoute});

  /// Current top-level route path, used to highlight the active entry.
  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Text(
                'Book Reader',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final entry in mainDrawerEntries)
                    _DrawerTile(
                      entry: entry,
                      selected: entry.routePath == currentRoute,
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            for (final entry in drawerFooterEntries)
              _DrawerTile(
                entry: entry,
                selected: entry.routePath == currentRoute,
              ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({required this.entry, required this.selected});

  final DrawerEntry entry;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        entry.icon,
        color: selected ? scheme.primary : null,
      ),
      title: Text(
        entry.label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? scheme.primary : null,
        ),
      ),
      selected: selected,
      onTap: () {
        Navigator.pop(context);
        if (!selected) context.go(entry.routePath);
      },
    );
  }
}
