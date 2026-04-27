import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Context passed to a [SelectionAction] when the user taps it.
class SelectionContext {
  const SelectionContext({
    required this.text,
    this.bookId,
    this.bookSeries,
    this.chapterIndex,
    this.charStart,
    this.charEnd,
  });

  final String text;
  final int? bookId;

  /// `Book.series` of the book the selection lives in, if any. Used by
  /// the Dictionary action to scope newly-created dictionaries.
  final String? bookSeries;

  /// Chapter the selection lives in (EPUB only).
  final int? chapterIndex;

  /// Absolute character offsets within the chapter `<body>` of the
  /// selection's start and end. Together with [chapterIndex] these are
  /// what the Citation action persists so the highlight can be re-drawn
  /// on later opens.
  final int? charStart;
  final int? charEnd;
}

/// One entry in the popup menu that appears above selected text in the
/// reader. Add new menu options by appending to the
/// [selectionActionsProvider] list — no other code needs to change.
class SelectionAction {
  const SelectionAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.onTap,
    this.overflow = false,
  });

  /// Stable identifier used to persist user customization (order +
  /// overflow flag). Lowercase snake_case.
  final String id;

  final IconData icon;
  final String label;

  /// When true, this action lives behind the popup's "…" overflow
  /// button instead of the inline row. New actions default to
  /// overflow=true so the inline row stays compact; promote to
  /// inline by setting this flag false.
  final bool overflow;

  /// Runs when the user taps the action. Receives the reader's
  /// [BuildContext] so the action can show modal sheets / dialogs.
  /// Return a short confirmation string to be shown as a SnackBar, or
  /// null for no toast.
  final Future<String?> Function(
    BuildContext context,
    WidgetRef ref,
    SelectionContext ctx,
  ) onTap;

  SelectionAction copyWith({bool? overflow}) => SelectionAction(
        id: id,
        icon: icon,
        label: label,
        onTap: onTap,
        overflow: overflow ?? this.overflow,
      );
}
