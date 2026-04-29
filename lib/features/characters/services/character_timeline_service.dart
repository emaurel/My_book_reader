import 'dart:io';

import 'package:epubx/epubx.dart' as epubx;

import '../../library/domain/book.dart';
import '../data/character_repository.dart';

/// One bar on the timeline — mentions of the character in a given
/// chapter of the source book.
class TimelinePoint {
  TimelinePoint({
    required this.chapterIndex,
    required this.chapterTitle,
    required this.mentions,
  });

  final int chapterIndex;
  final String chapterTitle;
  final int mentions;
}

class CharacterTimelineService {
  CharacterTimelineService(this._characters);

  final CharacterRepository _characters;

  /// Counts occurrences of [characterId]'s name and aliases per chapter
  /// of [book]. Only EPUB is supported in v1 — for PDFs we'd have to
  /// re-render text per page which is expensive; the bar is empty.
  Future<List<TimelinePoint>> compute({
    required int characterId,
    required Book book,
  }) async {
    if (book.format != BookFormat.epub) return const [];

    final aliases = await _characters.aliasesForCharacter(characterId);
    final all = await _characters.listAll();
    final character = all.firstWhere(
      (c) => c.id == characterId,
      orElse: () => throw StateError('Character not found'),
    );
    final tokens = <String>{character.name, ...aliases}
        .map((s) => s.trim())
        .where((s) => s.length >= 2)
        .toSet()
        .toList();
    if (tokens.isEmpty) return const [];

    final file = File(book.filePath);
    if (!await file.exists()) return const [];
    final bytes = await file.readAsBytes();
    final epub = await epubx.EpubReader.readBook(bytes);
    final chapters = _flatten(epub.Chapters ?? []);
    final result = <TimelinePoint>[];

    // Build a single regex covering every token; word-boundary aware.
    final escaped = tokens.map(RegExp.escape).join('|');
    final re = RegExp(r'\b(' + escaped + r')\b', caseSensitive: false);

    for (var i = 0; i < chapters.length; i++) {
      final ch = chapters[i];
      final html = ch.HtmlContent ?? '';
      final text = html.replaceAll(RegExp(r'<[^>]+>'), ' ');
      final count = re.allMatches(text).length;
      result.add(TimelinePoint(
        chapterIndex: i,
        chapterTitle: ch.Title?.trim().isNotEmpty == true
            ? ch.Title!
            : 'Chapter ${i + 1}',
        mentions: count,
      ));
    }
    return result;
  }

  List<epubx.EpubChapter> _flatten(List<epubx.EpubChapter> input) {
    final out = <epubx.EpubChapter>[];
    for (final c in input) {
      out.add(c);
      final subs = c.SubChapters;
      if (subs != null && subs.isNotEmpty) {
        out.addAll(_flatten(subs));
      }
    }
    return out;
  }
}
