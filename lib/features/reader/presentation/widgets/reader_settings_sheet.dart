import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../providers/reader_settings_provider.dart';

class ReaderSettingsSheet extends ConsumerWidget {
  const ReaderSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel('Theme'),
            const SizedBox(height: 8),
            Row(
              children: ReaderTheme.values.map((t) {
                final selected = settings.theme == t;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _ThemeSwatch(
                      theme: t,
                      selected: selected,
                      onTap: () => notifier.setTheme(t),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),
            const _SectionLabel('Font'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: settings.fontFamily,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: availableFonts
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (v) {
                if (v != null) notifier.setFontFamily(v);
              },
            ),

            const SizedBox(height: 20),
            _SliderRow(
              label: 'Size',
              value: settings.fontSize,
              min: 12,
              max: 32,
              divisions: 20,
              display: settings.fontSize.toStringAsFixed(0),
              onChanged: notifier.setFontSize,
            ),
            _SliderRow(
              label: 'Line height',
              value: settings.lineHeight,
              min: 1.0,
              max: 2.2,
              divisions: 12,
              display: settings.lineHeight.toStringAsFixed(2),
              onChanged: notifier.setLineHeight,
            ),
            _SliderRow(
              label: 'Margin',
              value: settings.horizontalPadding,
              min: 8,
              max: 48,
              divisions: 10,
              display: settings.horizontalPadding.toStringAsFixed(0),
              onChanged: notifier.setPadding,
            ),

            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Keep screen on'),
              value: settings.keepScreenOn,
              onChanged: notifier.setKeepScreenOn,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final ReaderTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ringColor = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: theme.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? ringColor : Colors.black12,
                width: selected ? 2 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'Aa',
              style: TextStyle(
                color: theme.foreground,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(theme.label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            display,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
