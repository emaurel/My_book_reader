import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/locale/locale_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/navigation/main_drawer.dart';
import '../../library/providers/library_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final showDocs = ref.watch(showDocumentsProvider);
    final locale = ref.watch(localeProvider);
    final l = AppLocalizations.of(context);

    return Scaffold(
      drawer: const MainDrawer(currentRoute: '/settings'),
      appBar: AppBar(title: Text(l.navSettings)),
      body: ListView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(context).bottom + 24,
        ),
        children: [
          _SectionHeader(l.settingsLibrary),
          SwitchListTile(
            title: Text(l.settingsShowDocuments),
            subtitle: Text(l.settingsShowDocumentsSubtitle),
            value: showDocs,
            onChanged: (v) =>
                ref.read(showDocumentsProvider.notifier).set(v),
          ),
          const Divider(),
          _SectionHeader(l.settingsReader),
          ListTile(
            title: Text(l.settingsSelectionMenu),
            subtitle: Text(l.settingsSelectionMenuSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/selection-menu'),
          ),
          const Divider(),
          _SectionHeader(l.settingsLanguage),
          RadioListTile<Locale?>(
            title: Text(l.settingsLanguageSystem),
            value: null,
            groupValue: locale,
            onChanged: (v) =>
                ref.read(localeProvider.notifier).set(v),
          ),
          RadioListTile<Locale?>(
            title: Text(l.languageEnglish),
            value: const Locale('en'),
            groupValue: locale,
            onChanged: (v) =>
                ref.read(localeProvider.notifier).set(v),
          ),
          RadioListTile<Locale?>(
            title: Text(l.languageFrench),
            value: const Locale('fr'),
            groupValue: locale,
            onChanged: (v) =>
                ref.read(localeProvider.notifier).set(v),
          ),
          RadioListTile<Locale?>(
            title: Text(l.languageSwedish),
            value: const Locale('sv'),
            groupValue: locale,
            onChanged: (v) =>
                ref.read(localeProvider.notifier).set(v),
          ),
          const Divider(),
          _SectionHeader(l.settingsAppearance),
          RadioListTile<ThemeMode>(
            title: Text(l.settingsAppearanceFollowSystem),
            value: ThemeMode.system,
            groupValue: mode,
            onChanged: (v) =>
                v != null ? ref.read(themeModeProvider.notifier).set(v) : null,
          ),
          RadioListTile<ThemeMode>(
            title: Text(l.settingsAppearanceLight),
            value: ThemeMode.light,
            groupValue: mode,
            onChanged: (v) =>
                v != null ? ref.read(themeModeProvider.notifier).set(v) : null,
          ),
          RadioListTile<ThemeMode>(
            title: Text(l.settingsAppearanceDark),
            value: ThemeMode.dark,
            groupValue: mode,
            onChanged: (v) =>
                v != null ? ref.read(themeModeProvider.notifier).set(v) : null,
          ),
          const Divider(),
          _SectionHeader(l.settingsAbout),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (_, snap) => ListTile(
              title: const Text('Lorekeeper'),
              subtitle: Text(
                snap.hasData
                    ? 'Version ${snap.data!.version} '
                        '(build ${snap.data!.buildNumber})'
                    : 'Version …',
              ),
            ),
          ),
          ListTile(
            title: Text(l.settingsSupportedFormats),
            subtitle: const Text('EPUB, PDF, TXT, AZW, AZW3, MOBI'),
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
