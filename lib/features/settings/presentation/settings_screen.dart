import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_provider.dart';
import '../../library/providers/library_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final showDocs = ref.watch(showDocumentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Library'),
          SwitchListTile(
            title: const Text('Show documents'),
            subtitle: const Text('Include PDFs and TXT files alongside books'),
            value: showDocs,
            onChanged: (v) =>
                ref.read(showDocumentsProvider.notifier).set(v),
          ),
          const Divider(),
          const _SectionHeader('Appearance'),
          RadioListTile<ThemeMode>(
            title: const Text('Follow system'),
            value: ThemeMode.system,
            groupValue: mode,
            onChanged: (v) =>
                v != null ? ref.read(themeModeProvider.notifier).set(v) : null,
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Light'),
            value: ThemeMode.light,
            groupValue: mode,
            onChanged: (v) =>
                v != null ? ref.read(themeModeProvider.notifier).set(v) : null,
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Dark'),
            value: ThemeMode.dark,
            groupValue: mode,
            onChanged: (v) =>
                v != null ? ref.read(themeModeProvider.notifier).set(v) : null,
          ),
          const Divider(),
          const _SectionHeader('About'),
          const ListTile(
            title: Text('Book Reader'),
            subtitle: Text('Version 0.1.0'),
          ),
          const ListTile(
            title: Text('Supported formats'),
            subtitle: Text('EPUB, PDF, TXT'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}
