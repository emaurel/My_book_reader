import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../reader/selection/selection_action.dart';
import '../../reader/selection/selection_actions_provider.dart';

class SelectionMenuSettingsScreen extends ConsumerWidget {
  const SelectionMenuSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.watch(selectionActionsProvider);
    final notifier = ref.read(selectionMenuConfigProvider.notifier);
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.settingsSelectionMenu),
        actions: [
          IconButton(
            tooltip: l.settingsSelectionMenuResetTooltip,
            icon: const Icon(Icons.restore),
            onPressed: notifier.reset,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              l.settingsSelectionMenuHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: ReorderableListView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewPaddingOf(context).bottom + 24,
              ),
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex--;
                final reordered = [
                  for (final a in actions)
                    SelectionMenuEntry(id: a.id, overflow: a.overflow),
                ];
                final moved = reordered.removeAt(oldIndex);
                reordered.insert(newIndex, moved);
                notifier.setEntries(reordered);
              },
              children: [
                for (final a in actions) _ActionTile(key: ValueKey(a.id), action: a),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends ConsumerWidget {
  const _ActionTile({super.key, required this.action});

  final SelectionAction action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(selectionMenuConfigProvider.notifier);
    return ListTile(
      leading: Icon(action.icon),
      title: Text(action.label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppLocalizations.of(context).settingsSelectionMenuInOverflow),
          const SizedBox(width: 8),
          Switch(
            value: action.overflow,
            onChanged: (v) async {
              // Snapshot current ordered state so the toggle preserves
              // any reorders the user has already made.
              final ordered = ref.read(selectionMenuOrderedProvider);
              await notifier.setEntries([
                for (final e in ordered)
                  e.id == action.id
                      ? SelectionMenuEntry(id: e.id, overflow: v)
                      : e,
              ]);
            },
          ),
          const SizedBox(width: 8),
          const Icon(Icons.drag_handle),
        ],
      ),
    );
  }
}
