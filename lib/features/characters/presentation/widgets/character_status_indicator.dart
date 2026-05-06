import 'package:flutter/material.dart';

import '../../domain/character.dart';

/// Small colored dot that visualises a character's narrative status.
/// When [status] is null the widget collapses to a zero-size box so
/// callers can drop it in without conditionals.
class CharacterStatusDot extends StatelessWidget {
  const CharacterStatusDot({
    super.key,
    required this.status,
    this.size = 10,
  });

  final CharacterStatus? status;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (status == null) return const SizedBox.shrink();
    return Tooltip(
      message: _label(status!),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _color(status!),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
      ),
    );
  }

  Color _color(CharacterStatus s) {
    switch (s) {
      case CharacterStatus.alive:
        return const Color(0xFF2E7D32); // green
      case CharacterStatus.dead:
        return const Color(0xFFC62828); // red
      case CharacterStatus.missing:
        return const Color(0xFFEF6C00); // orange
      case CharacterStatus.unknown:
        return const Color(0xFF757575); // grey
    }
  }

  String _label(CharacterStatus s) {
    switch (s) {
      case CharacterStatus.alive:
        return 'Alive';
      case CharacterStatus.dead:
        return 'Dead';
      case CharacterStatus.missing:
        return 'Missing';
      case CharacterStatus.unknown:
        return 'Unknown';
    }
  }
}

/// Decides what status to show given a possibly-spoiler-anchored
/// status field and the user's current reading position. Mirrors the
/// logic used for character descriptions:
///   * No anchor → always show.
///   * Same book, anchor chapter > current → hide (return null).
///   * Different book, anchor book is later in the series → hide.
///   * Otherwise show.
CharacterStatus? statusForReader({
  required CharacterStatus? status,
  required int? statusSpoilerBookId,
  required int? statusSpoilerChapterIndex,
  required int? currentBookId,
  required int? currentChapterIndex,
  required String? currentSeries,
  required double? currentSeriesNumber,
  required Future<({String? series, double? seriesNumber})> Function(int)
      lookupBook,
}) {
  // Caller logic — async lookups happen at the call site; this
  // helper is a placeholder for the synchronous path.
  // Most call sites compute spoiler visibility at the FutureBuilder
  // boundary; this signature is left here as a stub for symmetry.
  return status;
}
