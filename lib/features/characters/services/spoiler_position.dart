import '../../library/domain/book.dart';
import '../../library/data/book_repository.dart';
import '../domain/character.dart';
import '../domain/character_status_entry.dart';

/// Snapshot of where the user currently is in their reading. Lets every
/// "is this metadata a spoiler?" call site share the same comparison
/// rules instead of re-implementing series-number logic each time.
class ReaderPosition {
  const ReaderPosition({
    required this.bookId,
    required this.chapterIndex,
    required this.pageInChapter,
    this.series,
    this.seriesNumber,
  });

  final int bookId;
  final int chapterIndex;
  final int pageInChapter;
  final String? series;
  final double? seriesNumber;
}

/// One anchor (book, chapter, page) tied to some piece of metadata —
/// description, status entry, relationship, character first-appearance.
/// A null book means "no anchor"; the caller should treat that as
/// "always visible".
class SpoilerAnchor {
  const SpoilerAnchor({
    required this.bookId,
    this.chapterIndex,
    this.pageInChapter,
    this.bookSeries,
    this.bookSeriesNumber,
  });

  final int? bookId;
  final int? chapterIndex;
  final int? pageInChapter;

  /// Optional metadata about [bookId] that lets us compare across books
  /// using series_number. If null, callers fall back to "same book or
  /// untestable".
  final String? bookSeries;
  final double? bookSeriesNumber;

  bool get isAnchored => bookId != null || chapterIndex != null;
}

/// Result of comparing an anchor to the reader's current position.
enum AnchorOrder {
  /// Anchor is past the reader — metadata should be hidden as a spoiler.
  ahead,

  /// Anchor is at-or-before the reader — metadata is safe to show.
  reached,

  /// Anchor sits in a different series the reader hasn't opened or that
  /// has no series_number to compare against. Defaults to "reached"
  /// because hiding cross-series content the user added on purpose
  /// would be too aggressive.
  incomparable,
}

/// Compares an anchor to a reader position. The [position] may be null
/// when the user is outside the reader (e.g. on the Characters screen
/// without an open book) — in that case every anchor is treated as
/// reached, so lists show fully unfiltered content.
AnchorOrder compareAnchor(SpoilerAnchor anchor, ReaderPosition? position) {
  if (!anchor.isAnchored) return AnchorOrder.reached;
  if (position == null) return AnchorOrder.reached;
  if (anchor.bookId == null) {
    // Chapter-only anchor (legacy) — treat as if it's in the current
    // book so we still gate by chapter.
    return _compareWithinBook(
      anchorChapter: anchor.chapterIndex,
      anchorPage: anchor.pageInChapter,
      readerChapter: position.chapterIndex,
      readerPage: position.pageInChapter,
    );
  }
  if (anchor.bookId == position.bookId) {
    return _compareWithinBook(
      anchorChapter: anchor.chapterIndex,
      anchorPage: anchor.pageInChapter,
      readerChapter: position.chapterIndex,
      readerPage: position.pageInChapter,
    );
  }
  // Different book — series_number lets us order them on the timeline.
  if (anchor.bookSeries == null ||
      position.series == null ||
      anchor.bookSeries != position.series ||
      anchor.bookSeriesNumber == null ||
      position.seriesNumber == null) {
    return AnchorOrder.incomparable;
  }
  if (anchor.bookSeriesNumber! > position.seriesNumber!) {
    return AnchorOrder.ahead;
  }
  return AnchorOrder.reached;
}

AnchorOrder _compareWithinBook({
  required int? anchorChapter,
  required int? anchorPage,
  required int readerChapter,
  required int readerPage,
}) {
  final ach = anchorChapter ?? 0;
  if (readerChapter < ach) return AnchorOrder.ahead;
  if (readerChapter > ach) return AnchorOrder.reached;
  // Same chapter — compare pages. A null page means "from the
  // beginning of the chapter".
  final ap = anchorPage ?? 0;
  if (readerPage < ap) return AnchorOrder.ahead;
  return AnchorOrder.reached;
}

/// Loads the metadata needed to attach to anchors that point at books
/// the resolver may not have seen yet. Caches per call so a list of
/// 50 entries doesn't issue 50 separate book lookups.
class BookMetadataCache {
  BookMetadataCache(this._repo);
  final BookRepository _repo;
  final Map<int, Book?> _cache = {};

  Future<Book?> get(int? id) async {
    if (id == null) return null;
    if (_cache.containsKey(id)) return _cache[id];
    final b = await _repo.getById(id);
    _cache[id] = b;
    return b;
  }

  Future<SpoilerAnchor> hydrate({
    required int? bookId,
    int? chapterIndex,
    int? pageInChapter,
  }) async {
    final book = await get(bookId);
    return SpoilerAnchor(
      bookId: bookId,
      chapterIndex: chapterIndex,
      pageInChapter: pageInChapter,
      bookSeries: book?.series,
      bookSeriesNumber: book?.seriesNumber,
    );
  }
}

/// Pairing of a status entry with its hydrated anchor. Pre-computed
/// once so the resolver can run synchronously per reader position —
/// the timeline chart resolves status for every chapter and would
/// otherwise pay an async cost per bar.
class HydratedStatusEntry {
  HydratedStatusEntry(this.entry, this.anchor);
  final CharacterStatusEntry entry;
  final SpoilerAnchor anchor;
}

/// Concrete status value resolved at a reader position. Callers
/// combine this with the user's custom-status list to render a dot /
/// label / bar — see `statusDisplayFor` in the indicator widget file.
class ResolvedStatus {
  const ResolvedStatus({required this.status, this.customStatusId});
  final CharacterStatus status;
  final int? customStatusId;
}

/// Resolves a character's effective status at the reader's position by
/// finding the timeline entry with the latest *in-narrative* anchor
/// the reader has already reached. Falls back to the character's
/// default (`status` + `statusCustomId`) when no entry has been
/// reached yet.
Future<ResolvedStatus> resolveStatusAt({
  required Character character,
  required List<CharacterStatusEntry> entries,
  required ReaderPosition? position,
  required BookMetadataCache books,
}) async {
  if (entries.isEmpty) {
    return ResolvedStatus(
      status: character.status,
      customStatusId: character.statusCustomId,
    );
  }
  final hydrated = <HydratedStatusEntry>[];
  for (final e in entries) {
    hydrated.add(HydratedStatusEntry(
      e,
      await books.hydrate(
        bookId: e.bookId,
        chapterIndex: e.chapterIndex,
        pageInChapter: e.pageInChapter,
      ),
    ));
  }
  return resolveStatusAtSync(
    character: character,
    entries: hydrated,
    position: position,
  );
}

/// Synchronous resolver for callers that have already hydrated their
/// entries (e.g. the per-chapter timeline chart, which resolves the
/// same entries against many positions).
ResolvedStatus resolveStatusAtSync({
  required Character character,
  required List<HydratedStatusEntry> entries,
  required ReaderPosition? position,
}) {
  CharacterStatusEntry? best;
  SpoilerAnchor? bestAnchor;
  for (final h in entries) {
    final order = compareAnchor(h.anchor, position);
    if (order == AnchorOrder.ahead) continue;
    if (best == null ||
        _anchorIsLater(h.anchor, bestAnchor!) ||
        h.entry.createdAt.isAfter(best.createdAt)) {
      best = h.entry;
      bestAnchor = h.anchor;
    }
  }
  if (best == null) {
    return ResolvedStatus(
      status: character.status,
      customStatusId: character.statusCustomId,
    );
  }
  return ResolvedStatus(
    status: best.status,
    customStatusId: best.customStatusId,
  );
}

/// True when [a] sits later in the narrative than [b]. Both anchors
/// are assumed hydrated (book series_number filled in when available).
bool _anchorIsLater(SpoilerAnchor a, SpoilerAnchor b) {
  // Cross-series or unanchored — fall back to false; the createdAt
  // tie-breaker in resolveStatusAt picks the right entry.
  if (a.bookSeriesNumber != null && b.bookSeriesNumber != null) {
    if (a.bookSeriesNumber! > b.bookSeriesNumber!) return true;
    if (a.bookSeriesNumber! < b.bookSeriesNumber!) return false;
  } else if (a.bookId != b.bookId) {
    return false;
  }
  final ach = a.chapterIndex ?? 0;
  final bch = b.chapterIndex ?? 0;
  if (ach > bch) return true;
  if (ach < bch) return false;
  return (a.pageInChapter ?? 0) > (b.pageInChapter ?? 0);
}

/// True when the character's first-appearance anchor sits past the
/// reader's position. Characters screen renders these as a hidden
/// placeholder so the reader doesn't even know they exist yet.
Future<bool> isFirstSeenAhead({
  required Character character,
  required ReaderPosition? position,
  required BookMetadataCache books,
}) async {
  if (!character.hasFirstSeenAnchor) return false;
  if (position == null) return false;
  final anchor = await books.hydrate(
    bookId: character.firstSeenBookId,
    chapterIndex: character.firstSeenChapterIndex,
    pageInChapter: character.firstSeenPageInChapter,
  );
  return compareAnchor(anchor, position) == AnchorOrder.ahead;
}
