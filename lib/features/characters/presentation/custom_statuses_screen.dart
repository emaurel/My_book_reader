import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/custom_status.dart';
import '../providers/character_provider.dart';
import 'widgets/character_status_editor.dart';

/// Screen for managing user-defined statuses — name + color, plus
/// delete. Reachable from the Characters screen's app bar. The four
/// built-in statuses (alive / dead / missing / unknown) are not
/// listed here; they're hardcoded.
class CustomStatusesScreen extends ConsumerWidget {
  const CustomStatusesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final customsAsync = ref.watch(customStatusesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom statuses'),
        actions: [
          IconButton(
            tooltip: 'New status',
            icon: const Icon(Icons.add),
            onPressed: () => showCreateCustomStatusSheet(context, ref),
          ),
        ],
      ),
      body: customsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.palette_outlined,
                      size: 56,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No custom statuses yet',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap + to add one (e.g. Imprisoned, Cursed). '
                      'Custom statuses appear in the chip picker '
                      'next to the four built-ins.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (_, i) => _Row(status: list[i]),
          );
        },
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.status});
  final CustomStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Color(status.colorArgb),
          shape: BoxShape.circle,
        ),
      ),
      title: Text(status.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => _edit(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final picked = await showEditCustomStatusSheet(
      context,
      initialName: status.name,
      initialColorArgb: status.colorArgb,
    );
    if (picked == null || status.id == null) return;
    await ref.read(characterRepositoryProvider).updateCustomStatus(
          id: status.id!,
          name: picked.name,
          colorArgb: picked.colorArgb,
        );
    ref.read(characterRevisionProvider.notifier).state++;
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Delete "${status.name}"?'),
        content: const Text(
          'Characters and entries pointing at this status will fall '
          'back to their built-in placeholder.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || status.id == null) return;
    await ref.read(characterRepositoryProvider).deleteCustomStatus(status.id!);
    ref.read(characterRevisionProvider.notifier).state++;
  }
}
