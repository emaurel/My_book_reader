import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../characters/presentation/widgets/add_character_description_sheet.dart';
import '../../citations/providers/citation_provider.dart';
import '../../dictionary/presentation/widgets/add_to_dictionary_sheet.dart';
import 'selection_action.dart';

/// Single source of truth for the reader's selection menu. Append a
/// [SelectionAction] here and it will appear automatically — no changes
/// to the reader, popup widget, or dispatch logic are needed.
final selectionActionsProvider = Provider<List<SelectionAction>>((ref) {
  return [
    SelectionAction(
      icon: Icons.copy_outlined,
      label: 'Copy',
      onTap: (context, ref, ctx) async {
        await Clipboard.setData(ClipboardData(text: ctx.text));
        return 'Copied';
      },
    ),
    SelectionAction(
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
      icon: Icons.person_outline,
      label: 'Character',
      onTap: (context, ref, ctx) async {
        final saved = await showAddCharacterDescriptionSheet(
          context,
          text: ctx.text,
          bookId: ctx.bookId,
          bookSeries: ctx.bookSeries,
        );
        return saved == true ? 'Saved character description' : null;
      },
    ),
    SelectionAction(
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
