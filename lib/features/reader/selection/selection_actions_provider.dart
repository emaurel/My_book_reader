import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../main.dart';
import '../../book_links/presentation/widgets/link_book_picker_sheet.dart';
import '../../book_links/providers/book_link_provider.dart';
import '../../characters/presentation/widgets/add_character_description_sheet.dart';
import '../../citations/providers/citation_provider.dart';
import '../../dictionary/presentation/widgets/add_to_dictionary_sheet.dart';
import '../../notes/presentation/widgets/add_note_sheet.dart';
import 'selection_action.dart';

const _selectionMenuPrefsKey = 'reader.selection_menu';

/// Built-in selection actions in their default order. Each has a
/// stable [SelectionAction.id] so the user's customization survives
/// app updates that add or rename actions.
final _baselineActionsProvider = Provider<List<SelectionAction>>((ref) {
  return [
    SelectionAction(
      id: 'copy',
      icon: Icons.copy_outlined,
      label: 'Copy',
      onTap: (context, ref, ctx) async {
        await Clipboard.setData(ClipboardData(text: ctx.text));
        return 'Copied';
      },
    ),
    SelectionAction(
      id: 'citation',
      icon: Icons.format_quote_outlined,
      label: 'Citation',
      onTap: (context, ref, ctx) async {
        await ref.read(citationsProvider.notifier).add(
              bookId: ctx.bookId,
              text: ctx.text,
              chapterIndex: ctx.chapterIndex,
              charStart: ctx.charStart,
              charEnd: ctx.charEnd,
            );
        return 'Saved citation';
      },
    ),
    SelectionAction(
      id: 'dictionary',
      icon: Icons.menu_book_outlined,
      label: 'Dictionary',
      onTap: (context, ref, ctx) async {
        final saved = await showAddToDictionarySheet(
          context,
          word: ctx.text,
          bookSeries: ctx.bookSeries,
        );
        return saved == true ? 'Added to dictionary' : null;
      },
    ),
    SelectionAction(
      id: 'character',
      icon: Icons.person_outline,
      label: 'Character',
      onTap: (context, ref, ctx) async {
        final saved = await showAddCharacterDescriptionSheet(
          context,
          text: ctx.text,
          bookId: ctx.bookId,
          chapterIndex: ctx.chapterIndex,
          bookSeries: ctx.bookSeries,
        );
        return saved == true ? 'Saved character description' : null;
      },
    ),
    SelectionAction(
      id: 'link',
      icon: Icons.link,
      label: 'Link',
      overflow: true,
      onTap: (context, ref, ctx) async {
        if (ctx.bookId == null) return 'Open a book to link';
        final pickedBookId = await showLinkBookPickerSheet(
          context,
          excludeBookId: ctx.bookId!,
        );
        if (pickedBookId == null) return null;
        await ref.read(bookLinksProvider.notifier).add(
              sourceBookId: ctx.bookId!,
              sourceChapterIndex: ctx.chapterIndex,
              sourceCharStart: ctx.charStart,
              sourceCharEnd: ctx.charEnd,
              targetBookId: pickedBookId,
              label: ctx.text,
            );
        return 'Linked';
      },
    ),
    SelectionAction(
      id: 'note',
      icon: Icons.sticky_note_2_outlined,
      label: 'Note',
      overflow: true,
      onTap: (context, ref, ctx) async {
        final id = await showAddNoteSheet(
          context,
          selectedText: ctx.text,
          bookId: ctx.bookId,
          chapterIndex: ctx.chapterIndex,
          charStart: ctx.charStart,
          charEnd: ctx.charEnd,
        );
        return id != null ? 'Note added' : null;
      },
    ),
    SelectionAction(
      id: 'translate',
      icon: Icons.translate,
      label: 'Translate',
      onTap: (context, ref, ctx) async {
        final encoded = Uri.encodeComponent(ctx.text);
        final url = Uri.parse(
          'https://translate.google.com/'
          '?sl=auto&tl=en&op=translate&text=$encoded',
        );
        final ok = await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
        return ok ? null : 'Could not open translator';
      },
    ),
  ];
});

/// Persisted menu config: an ordered list of `{id, overflow}` entries.
/// New baseline actions that aren't in the saved config get appended
/// at the end in their default order, preserving the user's tweaks
/// across app updates that introduce new actions.
class SelectionMenuEntry {
  const SelectionMenuEntry({required this.id, required this.overflow});
  final String id;
  final bool overflow;

  Map<String, dynamic> toJson() => {'id': id, 'overflow': overflow};
  factory SelectionMenuEntry.fromJson(Map<String, dynamic> j) =>
      SelectionMenuEntry(
        id: j['id'] as String,
        overflow: j['overflow'] as bool? ?? false,
      );
}

class SelectionMenuConfigNotifier
    extends StateNotifier<List<SelectionMenuEntry>> {
  SelectionMenuConfigNotifier(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;

  static List<SelectionMenuEntry> _load(SharedPreferences prefs) {
    final raw = prefs.getString(_selectionMenuPrefsKey);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map(SelectionMenuEntry.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _save() async {
    await _prefs.setString(
      _selectionMenuPrefsKey,
      jsonEncode(state.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> setEntries(List<SelectionMenuEntry> entries) async {
    state = entries;
    await _save();
  }

  Future<void> setOverflow(String id, bool overflow) async {
    state = [
      for (final e in state)
        e.id == id ? SelectionMenuEntry(id: id, overflow: overflow) : e,
    ];
    await _save();
  }

  Future<void> reset() async {
    state = const [];
    await _prefs.remove(_selectionMenuPrefsKey);
  }
}

final selectionMenuConfigProvider = StateNotifierProvider<
    SelectionMenuConfigNotifier, List<SelectionMenuEntry>>((ref) {
  return SelectionMenuConfigNotifier(ref.watch(sharedPreferencesProvider));
});

/// Single source of truth for the reader's selection menu. Combines
/// the [_baselineActionsProvider] with the user's saved
/// customization from [selectionMenuConfigProvider].
final selectionActionsProvider = Provider<List<SelectionAction>>((ref) {
  final baseline = ref.watch(_baselineActionsProvider);
  final config = ref.watch(selectionMenuConfigProvider);
  if (config.isEmpty) return baseline;

  final byId = {for (final a in baseline) a.id: a};
  final result = <SelectionAction>[];
  final used = <String>{};
  for (final entry in config) {
    final base = byId[entry.id];
    if (base == null) continue;
    used.add(entry.id);
    result.add(base.copyWith(overflow: entry.overflow));
  }
  for (final a in baseline) {
    if (!used.contains(a.id)) result.add(a);
  }
  return result;
});

/// Convenience: snapshot of the current ordered list as menu entries,
/// merged with any baseline actions not yet recorded. The settings
/// screen uses this to render the customization UI without forcing
/// the user to first interact with anything.
final selectionMenuOrderedProvider =
    Provider<List<SelectionMenuEntry>>((ref) {
  final actions = ref.watch(selectionActionsProvider);
  return [
    for (final a in actions)
      SelectionMenuEntry(id: a.id, overflow: a.overflow),
  ];
});
