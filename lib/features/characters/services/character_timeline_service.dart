import 'dart:io';

import 'package:epubx/epubx.dart' as epubx;

import '../../library/data/book_repository.dart';
import '../../library/domain/book.dart';
import '../data/character_repository.dart';
import '../domain/character.dart';
import 'spoiler_position.dart';

/// One bar on the timeline — mentions of the character in a given
/// chapter of the source book, plus the resolved status (built-in
/// enum + optional custom-id) that applies at that chapter so the
/// chart can colour each bar accordingly.
class TimelinePoint {
  TimelinePoint({
    required this.chapterIndex,
    required this.chapterTitle,
    required this.mentions,
    required this.status,
    this.customStatusId,
  });

  final int chapterIndex;
  final String chapterTitle;
  final int mentions;
  final CharacterStatus status;
  final int? customStatusId;
}

class CharacterTimelineService {
  CharacterTimelineService(this._characters, {BookRepository? books})
      : _books = books ?? BookRepository();

  final CharacterRepository _characters;
  final BookRepository _books;

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

    // Pre-hydrate every status entry's anchor so the per-chapter status
    // resolution below stays synchronous — otherwise we'd pay an async
    // round-trip per chapter × per entry.
    final entries = await _characters.listStatusEntries(characterId);
    final cache = BookMetadataCache(_books);
    final hydrated = <HydratedStatusEntry>[];
    for (final e in entries) {
      hydrated.add(HydratedStatusEntry(
        e,
        await cache.hydrate(
          bookId: e.bookId,
          chapterIndex: e.chapterIndex,
          pageInChapter: e.pageInChapter,
        ),
      ));
    }

    for (var i = 0; i < chapters.length; i++) {
      final ch = chapters[i];
      final html = ch.HtmlContent ?? '';
      final text = html.replaceAll(RegExp(r'<[^>]+>'), ' ');
      final count = re.allMatches(text).length;
      // Status the character is in at the start of this chapter — used
      // to colour the bar. Page is treated as 0 (start of chapter).
      final position = ReaderPosition(
        bookId: book.id ?? -1,
        chapterIndex: i,
        pageInChapter: 0,
        series: book.series,
        seriesNumber: book.seriesNumber,
      );
      final resolved = resolveStatusAtSync(
        character: character,
        entries: hydrated,
        position: position,
      );
      result.add(TimelinePoint(
        chapterIndex: i,
        chapterTitle: ch.Title?.trim().isNotEmpty == true
            ? ch.Title!
            : 'Chapter ${i + 1}',
        mentions: count,
        status: resolved.status,
        customStatusId: resolved.customStatusId,
      ));
    }
    return result;
  }

  /// Finds the earliest (book, chapter) where the character's name or
  /// any alias appears, scanning [books] in the order given. The caller
  /// is expected to pass series-ordered books so the answer reflects
  /// in-narrative order rather than file-system order. Returns null
  /// when nothing matches — likely all aliases are short, the books
  /// aren't EPUBs, or the character was added without ever being
  /// mentioned in the indexed library.
  Future<({Book book, int chapterIndex})?> findFirstAppearance({
    required int characterId,
    required List<Book> books,
  }) async {
    for (final book in books) {
      if (book.format != BookFormat.epub) continue;
      final points = await compute(characterId: characterId, book: book);
      for (final p in points) {
        if (p.mentions > 0) {
          return (book: book, chapterIndex: p.chapterIndex);
        }
      }
    }
    return null;
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
