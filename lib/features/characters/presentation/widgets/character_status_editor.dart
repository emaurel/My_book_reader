import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../library/data/book_repository.dart';
import '../../../library/domain/book.dart';
import '../../../library/providers/library_provider.dart';
import '../../../reader/providers/reader_position_provider.dart';
import '../../domain/character.dart';
import '../../domain/character_status_entry.dart';
import '../../domain/custom_status.dart';
import '../../providers/character_provider.dart';
import '../../services/character_timeline_service.dart';
import '../../services/spoiler_position.dart';
import 'character_status_indicator.dart';

/// Editable status timeline for a character. Renders the resolved
/// status (with dot) at the top, followed by the list of recorded
/// status changes. Each change anchors to a (book, chapter, page);
/// inside the reader the resolved status reflects what the user has
/// read so far. Outside the reader the latest entry wins.
///
/// When [currentBookId] / [currentChapterIndex] / [currentPageInChapter]
/// are non-null (i.e. shown from inside the reader), new entries
/// pre-fill their anchor with that position.
///
class CharacterStatusEditor extends ConsumerStatefulWidget {
  const CharacterStatusEditor({
    super.key,
    required this.character,
    this.currentBookId,
    this.currentChapterIndex,
    this.currentPageInChapter,
  });

  final Character character;
  final int? currentBookId;
  final int? currentChapterIndex;
  final int? currentPageInChapter;

  @override
  ConsumerState<CharacterStatusEditor> createState() =>
      _CharacterStatusEditorState();
}

class _CharacterStatusEditorState extends ConsumerState<CharacterStatusEditor> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final character = widget.character;
    final entries = character.id == null
        ? const AsyncValue<List<CharacterStatusEntry>>.data([])
        : ref.watch(statusEntriesForCharacterProvider(character.id!));
    // Display lookups need every custom (a saved entry might point at
    // a row from another series) — but the picker only offers the
    // ones in scope for this character.
    final allCustomsAsync = ref.watch(customStatusesProvider);
    final allCustoms = allCustomsAsync.maybeWhen(
      data: (list) => list,
      orElse: () => const <CustomStatus>[],
    );
    final scopedCustomsAsync =
        ref.watch(customStatusesForScopeProvider(character.series));
    final scopedCustoms = scopedCustomsAsync.maybeWhen(
      data: (list) => list,
      orElse: () => const <CustomStatus>[],
    );
    final resolved = character.id == null
        ? AsyncValue<ResolvedStatus>.data(ResolvedStatus(
            status: character.status,
            customStatusId: character.statusCustomId,
          ))
        : ref.watch(resolvedStatusForCharacterProvider(character.id!));
    final resolvedValue = resolved.maybeWhen(
      data: (r) => r,
      orElse: () => ResolvedStatus(
        status: character.status,
        customStatusId: character.statusCustomId,
      ),
    );
    final display = statusDisplayFor(
      builtIn: resolvedValue.status,
      customId: resolvedValue.customStatusId,
      customs: allCustoms,
    );
    final position = ref.watch(currentReaderPositionProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Status',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            CharacterStatusDot(
              color: display.color,
              label: display.label,
              size: 12,
            ),
            const SizedBox(width: 6),
            Text(display.label),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add change'),
              onPressed: character.id == null
                  ? null
                  : () => _showAddEntry(scopedCustoms),
            ),
          ],
        ),
        entries.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (list) {
            final synthetic = CharacterStatusEntry(
              characterId: character.id ?? -1,
              status: character.status,
              customStatusId: character.statusCustomId,
              bookId: character.firstSeenBookId,
              chapterIndex: character.firstSeenChapterIndex,
              pageInChapter: character.firstSeenPageInChapter,
              createdAt: character.createdAt,
            );
            return _TimelineList(
              entries: [synthetic, ...list],
              position: position,
              character: character,
              customs: allCustoms,
              scopedCustoms: scopedCustoms,
            );
          },
        ),
        const SizedBox(height: 4),
        _FirstSeenRow(
          character: character,
          currentBookId: widget.currentBookId,
          currentChapterIndex: widget.currentChapterIndex,
          currentPageInChapter: widget.currentPageInChapter,
        ),
      ],
    );
  }

  Future<void> _showAddEntry(List<CustomStatus> customs) async {
    final character = widget.character;
    final picked = await showModalBottomSheet<_StatusEntryEdit>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: _StatusEntrySheet(
          characterSeries: character.series,
          repo: ref.read(bookRepositoryProvider),
          customs: customs,
          initial: _StatusEntryEdit(
            status: CharacterStatus.alive,
            bookId: widget.currentBookId,
            chapterIndex: widget.currentChapterIndex,
            pageInChapter: widget.currentPageInChapter,
          ),
        ),
      ),
    );
    if (picked == null || character.id == null) return;
    await ref.read(characterRepositoryProvider).addStatusEntry(
          characterId: character.id!,
          status: picked.status,
          customStatusId: picked.customStatusId,
          bookId: picked.bookId,
          chapterIndex: picked.chapterIndex,
          pageInChapter: picked.pageInChapter,
          note: picked.note,
        );
    ref.read(characterRevisionProvider.notifier).state++;
  }
}

/// Renders the entry list, silently hiding any entry whose anchor is
/// past the reader's current position. The hidden count is *not*
/// surfaced — even acknowledging "more changes ahead" leaks that the
/// character's status is going to change. With no position (Characters
/// screen, no book open) every entry is shown.
class _TimelineList extends ConsumerWidget {
  const _TimelineList({
    required this.entries,
    required this.position,
    required this.character,
    required this.customs,
    required this.scopedCustoms,
  });

  final List<CharacterStatusEntry> entries;
  final ReaderPosition? position;
  final Character character;

  /// Every custom in the database — used so a saved entry's color/
  /// label resolves even when the row's series is different from
  /// this character's. Display lookup only.
  final List<CustomStatus> customs;

  /// Customs available to *pick* for this character (globals +
  /// matching series). Used by the edit-default sheet's chip grid.
  final List<CustomStatus> scopedCustoms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (position == null) {
      return _list(entries);
    }
    return FutureBuilder<List<CharacterStatusEntry>>(
      future: _filter(ref),
      builder: (_, snap) {
        return _list(snap.data ?? entries);
      },
    );
  }

  Widget _list(List<CharacterStatusEntry> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in items)
            _StatusEntryRow(
              key: ValueKey(e.id ?? 'synthetic'),
              entry: e,
              character: character,
              customs: customs,
              scopedCustoms: scopedCustoms,
            ),
        ],
      ),
    );
  }

  Future<List<CharacterStatusEntry>> _filter(WidgetRef ref) async {
    final cache = BookMetadataCache(ref.read(bookRepositoryProvider));
    final out = <CharacterStatusEntry>[];
    for (final e in entries) {
      final anchor = await cache.hydrate(
        bookId: e.bookId,
        chapterIndex: e.chapterIndex,
        pageInChapter: e.pageInChapter,
      );
      if (compareAnchor(anchor, position) != AnchorOrder.ahead) {
        out.add(e);
      }
    }
    return out;
  }
}

class _StatusEntryRow extends ConsumerWidget {
  const _StatusEntryRow({
    super.key,
    required this.entry,
    required this.character,
    required this.customs,
    required this.scopedCustoms,
  });
  final CharacterStatusEntry entry;
  final Character character;
  final List<CustomStatus> customs;
  final List<CustomStatus> scopedCustoms;

  bool get _isSynthetic => entry.id == null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final display = statusDisplayFor(
      builtIn: entry.status,
      customId: entry.customStatusId,
      customs: customs,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          CharacterStatusDot(
            color: display.color,
            label: display.label,
            size: 8,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FutureBuilder<String>(
              future: _formatAnchor(ref, entry),
              builder: (_, snap) {
                final pos = snap.data ?? '...';
                final label = '${display.label} — $pos';
                final note = entry.note;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (note != null && note.isNotEmpty)
                      Text(
                        note,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                );
              },
            ),
          ),
          if (_isSynthetic)
            IconButton(
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit default status',
              onPressed: character.id == null
                  ? null
                  : () => _editDefault(context, ref),
            )
          else
            IconButton(
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close),
              tooltip: 'Remove',
              onPressed: () => _confirmDelete(context, ref),
            ),
        ],
      ),
    );
  }

  Future<void> _editDefault(BuildContext context, WidgetRef ref) async {
    final picked = await showModalBottomSheet<_StatusPick>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: _DefaultStatusSheet(
          initialStatus: character.status,
          initialCustomId: character.statusCustomId,
          customs: scopedCustoms,
          characterSeries: character.series,
        ),
      ),
    );
    if (picked == null || character.id == null) return;
    await ref.read(characterRepositoryProvider).setDefaultStatus(
          characterId: character.id!,
          status: picked.status,
          customStatusId: picked.customStatusId,
        );
    ref.read(characterRevisionProvider.notifier).state++;
  }

  Future<String> _formatAnchor(
    WidgetRef ref,
    CharacterStatusEntry e,
  ) async {
    if (e.bookId == null && e.chapterIndex == null) return 'Beginning';
    String? bookTitle;
    if (e.bookId != null) {
      final book = await ref.read(bookRepositoryProvider).getById(e.bookId!);
      bookTitle = book?.title;
    }
    final parts = <String>[];
    if (bookTitle != null) parts.add(bookTitle);
    if (e.chapterIndex != null) parts.add('Ch ${e.chapterIndex! + 1}');
    if (e.pageInChapter != null) parts.add('p ${e.pageInChapter! + 1}');
    return parts.join(' · ');
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    if (entry.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Remove status entry?'),
        content: const Text(
          'The character timeline reverts to the previous entry.',
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(characterRepositoryProvider).deleteStatusEntry(entry.id!);
    ref.read(characterRevisionProvider.notifier).state++;
  }
}

class _FirstSeenRow extends ConsumerStatefulWidget {
  const _FirstSeenRow({
    required this.character,
    this.currentBookId,
    this.currentChapterIndex,
    this.currentPageInChapter,
  });

  final Character character;
  final int? currentBookId;
  final int? currentChapterIndex;
  final int? currentPageInChapter;

  @override
  ConsumerState<_FirstSeenRow> createState() => _FirstSeenRowState();
}

class _FirstSeenRowState extends ConsumerState<_FirstSeenRow> {
  bool _detecting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final character = widget.character;
    final hasAnchor = character.hasFirstSeenAnchor;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            Icons.visibility_outlined,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: FutureBuilder<String>(
              future: _formatAnchor(),
              builder: (_, snap) {
                final body = hasAnchor
                    ? 'First seen: ${snap.data ?? '…'}'
                    : 'First seen: not set';
                return Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
          ),
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            icon: _detecting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(hasAnchor ? Icons.refresh : Icons.auto_fix_high),
            tooltip: hasAnchor
                ? 'Re-detect from book text'
                : 'Auto-detect from book text',
            onPressed:
                character.id == null || _detecting ? null : _autoDetect,
          ),
          TextButton(
            onPressed: character.id == null ? null : _editFirstSeen,
            child: Text(hasAnchor ? 'Edit' : 'Set'),
          ),
          if (hasAnchor)
            IconButton(
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close),
              tooltip: 'Clear',
              onPressed: character.id == null
                  ? null
                  : () async {
                      await ref
                          .read(characterRepositoryProvider)
                          .setFirstSeen(characterId: character.id!);
                      ref
                          .read(characterRevisionProvider.notifier)
                          .state++;
                    },
            ),
        ],
      ),
    );
  }

  Future<String> _formatAnchor() async {
    final character = widget.character;
    if (!character.hasFirstSeenAnchor) return 'not set';
    String? bookTitle;
    if (character.firstSeenBookId != null) {
      final book = await ref
          .read(bookRepositoryProvider)
          .getById(character.firstSeenBookId!);
      bookTitle = book?.title;
    }
    final parts = <String>[];
    if (bookTitle != null) parts.add(bookTitle);
    if (character.firstSeenChapterIndex != null) {
      parts.add('Ch ${character.firstSeenChapterIndex! + 1}');
    }
    if (character.firstSeenPageInChapter != null) {
      parts.add('p ${character.firstSeenPageInChapter! + 1}');
    }
    return parts.join(' · ');
  }

  Future<void> _editFirstSeen() async {
    final character = widget.character;
    final picked = await showModalBottomSheet<_AnchorEdit>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: _AnchorOnlySheet(
          title: 'First-seen anchor',
          characterSeries: character.series,
          repo: ref.read(bookRepositoryProvider),
          initial: _AnchorEdit(
            bookId: character.firstSeenBookId ?? widget.currentBookId,
            chapterIndex: character.firstSeenChapterIndex ??
                widget.currentChapterIndex,
            pageInChapter: character.firstSeenPageInChapter ??
                widget.currentPageInChapter,
          ),
        ),
      ),
    );
    if (picked == null || character.id == null) return;
    await ref.read(characterRepositoryProvider).setFirstSeen(
          characterId: character.id!,
          bookId: picked.bookId,
          chapterIndex: picked.chapterIndex,
          pageInChapter: picked.pageInChapter,
        );
    ref.read(characterRevisionProvider.notifier).state++;
  }

  /// Scans the character's series-scoped EPUBs in series-number order
  /// and saves the first chapter where the name (or any alias) appears.
  Future<void> _autoDetect() async {
    final character = widget.character;
    if (character.id == null) return;
    setState(() => _detecting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final books = await _seriesBooks();
      final hit = await CharacterTimelineService(
        ref.read(characterRepositoryProvider),
      ).findFirstAppearance(
        characterId: character.id!,
        books: books,
      );
      if (hit == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('No appearances found in your library.'),
          ),
        );
        return;
      }
      await ref.read(characterRepositoryProvider).setFirstSeen(
            characterId: character.id!,
            bookId: hit.book.id,
            chapterIndex: hit.chapterIndex,
          );
      ref.read(characterRevisionProvider.notifier).state++;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'First seen set: ${hit.book.title} · Ch ${hit.chapterIndex + 1}',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Detection failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  /// EPUBs that the character could plausibly appear in: series match
  /// for series-scoped characters, or every EPUB for global ones.
  /// Sorted by seriesNumber so the earliest book is scanned first.
  Future<List<Book>> _seriesBooks() async {
    final all = await ref.read(bookRepositoryProvider).getAll();
    final series = widget.character.series;
    final filtered = all
        .where((b) =>
            b.format == BookFormat.epub &&
            (series == null ||
                (b.series != null &&
                    b.series!.toLowerCase() == series.toLowerCase())))
        .toList();
    filtered.sort((a, b) {
      final an = a.seriesNumber;
      final bn = b.seriesNumber;
      if (an != null && bn != null) return an.compareTo(bn);
      if (an != null) return -1;
      if (bn != null) return 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return filtered;
  }
}

class _StatusEntryEdit {
  _StatusEntryEdit({
    required this.status,
    this.customStatusId,
    this.bookId,
    this.chapterIndex,
    this.pageInChapter,
    this.note,
  });
  CharacterStatus status;
  int? customStatusId;
  int? bookId;
  int? chapterIndex;
  int? pageInChapter;
  String? note;
}

class _AnchorEdit {
  _AnchorEdit({this.bookId, this.chapterIndex, this.pageInChapter});
  int? bookId;
  int? chapterIndex;
  int? pageInChapter;
}

/// Sheet for "add a status change" — status chip + book picker +
/// chapter/page inputs + optional note.
class _StatusEntrySheet extends StatefulWidget {
  const _StatusEntrySheet({
    required this.characterSeries,
    required this.repo,
    required this.initial,
    required this.customs,
  });

  final String? characterSeries;
  final BookRepository repo;
  final _StatusEntryEdit initial;
  final List<CustomStatus> customs;

  @override
  State<_StatusEntrySheet> createState() => _StatusEntrySheetState();
}

class _StatusEntrySheetState extends State<_StatusEntrySheet> {
  late CharacterStatus _status;
  int? _customId;
  int? _bookId;
  late final TextEditingController _chapterCtrl;
  late final TextEditingController _pageCtrl;
  late final TextEditingController _noteCtrl;
  late final Future<List<Book>> _booksFuture;

  @override
  void initState() {
    super.initState();
    _status = widget.initial.status;
    _customId = widget.initial.customStatusId;
    _bookId = widget.initial.bookId;
    _chapterCtrl = TextEditingController(
      text: widget.initial.chapterIndex != null
          ? (widget.initial.chapterIndex! + 1).toString()
          : '',
    );
    _pageCtrl = TextEditingController(
      text: widget.initial.pageInChapter != null
          ? (widget.initial.pageInChapter! + 1).toString()
          : '',
    );
    _noteCtrl = TextEditingController(text: widget.initial.note ?? '');
    _booksFuture = _loadBooks();
  }

  Future<List<Book>> _loadBooks() async {
    final all = await widget.repo.getAll();
    final series = widget.characterSeries;
    // Series-scoped characters can only change status inside books of
    // their own series — including untagged books here would let the
    // user pick a totally unrelated standalone novel as the anchor.
    // Global characters (no series) keep the full list since they
    // could plausibly appear anywhere.
    final filtered = series == null
        ? all
        : all
            .where((b) =>
                b.series != null &&
                b.series!.toLowerCase() == series.toLowerCase())
            .toList();
    filtered.sort((a, b) {
      final an = a.seriesNumber;
      final bn = b.seriesNumber;
      if (an != null && bn != null) return an.compareTo(bn);
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return filtered;
  }

  @override
  void dispose() {
    _chapterCtrl.dispose();
    _pageCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status change', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            _StatusChipGrid(
              builtIn: _customId == null ? _status : null,
              customId: _customId,
              customs: widget.customs,
              characterSeries: widget.characterSeries,
              onPickBuiltIn: (s) => setState(() {
                _status = s;
                _customId = null;
              }),
              onPickCustom: (id) => setState(() => _customId = id),
              onCreatedCustom: (id) => setState(() => _customId = id),
            ),
            const SizedBox(height: 16),
            Text(
              'Anchor',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pick when the character starts being this status. Readers '
              'before this point see the previous entry (or the default).',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Book>>(
              future: _booksFuture,
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const LinearProgressIndicator();
                }
                final books = snap.data!;
                final present = _bookId != null &&
                    books.any((b) => b.id == _bookId);
                return DropdownButtonFormField<int?>(
                  initialValue: present ? _bookId : null,
                  decoration: const InputDecoration(
                    labelText: 'Book',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('— None —'),
                    ),
                    for (final b in books)
                      DropdownMenuItem<int?>(
                        value: b.id,
                        child: Text(
                          b.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (id) => setState(() => _bookId = id),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _chapterCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Chapter',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _pageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Page',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final ch = int.tryParse(_chapterCtrl.text.trim());
                    final pg = int.tryParse(_pageCtrl.text.trim());
                    final note = _noteCtrl.text.trim();
                    Navigator.pop(
                      context,
                      _StatusEntryEdit(
                        status: _status,
                        customStatusId: _customId,
                        bookId: _bookId,
                        chapterIndex:
                            ch != null && ch > 0 ? ch - 1 : null,
                        pageInChapter:
                            pg != null && pg > 0 ? pg - 1 : null,
                        note: note.isEmpty ? null : note,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet for editing a (book, chapter, page) anchor — used by the
/// "first seen" row. No status chips.
class _AnchorOnlySheet extends StatefulWidget {
  const _AnchorOnlySheet({
    required this.title,
    required this.characterSeries,
    required this.repo,
    required this.initial,
  });
  final String title;
  final String? characterSeries;
  final BookRepository repo;
  final _AnchorEdit initial;

  @override
  State<_AnchorOnlySheet> createState() => _AnchorOnlySheetState();
}

class _AnchorOnlySheetState extends State<_AnchorOnlySheet> {
  int? _bookId;
  late final TextEditingController _chapterCtrl;
  late final TextEditingController _pageCtrl;
  late final Future<List<Book>> _booksFuture;

  @override
  void initState() {
    super.initState();
    _bookId = widget.initial.bookId;
    _chapterCtrl = TextEditingController(
      text: widget.initial.chapterIndex != null
          ? (widget.initial.chapterIndex! + 1).toString()
          : '',
    );
    _pageCtrl = TextEditingController(
      text: widget.initial.pageInChapter != null
          ? (widget.initial.pageInChapter! + 1).toString()
          : '',
    );
    _booksFuture = _loadBooks();
  }

  Future<List<Book>> _loadBooks() async {
    final all = await widget.repo.getAll();
    final series = widget.characterSeries;
    // Series-scoped characters can only change status inside books of
    // their own series — including untagged books here would let the
    // user pick a totally unrelated standalone novel as the anchor.
    // Global characters (no series) keep the full list since they
    // could plausibly appear anywhere.
    final filtered = series == null
        ? all
        : all
            .where((b) =>
                b.series != null &&
                b.series!.toLowerCase() == series.toLowerCase())
            .toList();
    filtered.sort((a, b) {
      final an = a.seriesNumber;
      final bn = b.seriesNumber;
      if (an != null && bn != null) return an.compareTo(bn);
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return filtered;
  }

  @override
  void dispose() {
    _chapterCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            FutureBuilder<List<Book>>(
              future: _booksFuture,
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const LinearProgressIndicator();
                }
                final books = snap.data!;
                final present = _bookId != null &&
                    books.any((b) => b.id == _bookId);
                return DropdownButtonFormField<int?>(
                  initialValue: present ? _bookId : null,
                  decoration: const InputDecoration(
                    labelText: 'Book',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('— None —'),
                    ),
                    for (final b in books)
                      DropdownMenuItem<int?>(
                        value: b.id,
                        child: Text(
                          b.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (id) => setState(() => _bookId = id),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _chapterCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Chapter',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _pageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Page',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final ch = int.tryParse(_chapterCtrl.text.trim());
                    final pg = int.tryParse(_pageCtrl.text.trim());
                    Navigator.pop(
                      context,
                      _AnchorEdit(
                        bookId: _bookId,
                        chapterIndex:
                            ch != null && ch > 0 ? ch - 1 : null,
                        pageInChapter:
                            pg != null && pg > 0 ? pg - 1 : null,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Result of a default-status edit — captures both the built-in enum
/// and the optional custom-status pointer.
class _StatusPick {
  const _StatusPick(this.status, [this.customStatusId]);
  final CharacterStatus status;
  final int? customStatusId;
}

/// Tiny sheet for editing only the default status — no anchor inputs
/// because the synthetic first row implicitly anchors to first-seen.
class _DefaultStatusSheet extends StatefulWidget {
  const _DefaultStatusSheet({
    required this.initialStatus,
    required this.initialCustomId,
    required this.customs,
    required this.characterSeries,
  });
  final CharacterStatus initialStatus;
  final int? initialCustomId;
  final List<CustomStatus> customs;

  /// Series of the character being edited — passed to the chip grid
  /// so the "+ New status" sheet can pre-fill its scope.
  final String? characterSeries;

  @override
  State<_DefaultStatusSheet> createState() => _DefaultStatusSheetState();
}

class _DefaultStatusSheetState extends State<_DefaultStatusSheet> {
  late CharacterStatus _status = widget.initialStatus;
  late int? _customId = widget.initialCustomId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Default status", style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              "Used until a recorded change applies — set this when the "
              "character is first introduced as anything other than alive.",
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _StatusChipGrid(
              builtIn: _customId == null ? _status : null,
              customId: _customId,
              customs: widget.customs,
              characterSeries: widget.characterSeries,
              onPickBuiltIn: (s) => setState(() {
                _status = s;
                _customId = null;
              }),
              onPickCustom: (id) => setState(() => _customId = id),
              onCreatedCustom: (id) => setState(() => _customId = id),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    _StatusPick(_status, _customId),
                  ),
                  child: const Text("Save"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip grid shared by the status-entry sheet and the default-status
/// sheet: 4 built-in chips, then a chip per custom status (in their
/// own color), then a "+ New" chip that opens [showCreateCustomStatusSheet].
class _StatusChipGrid extends ConsumerWidget {
  const _StatusChipGrid({
    required this.builtIn,
    required this.customId,
    required this.customs,
    required this.characterSeries,
    required this.onPickBuiltIn,
    required this.onPickCustom,
    required this.onCreatedCustom,
  });

  /// Default series suggested in the "+ New status" creation sheet.
  /// Null means the picker is opened from a global character; new
  /// statuses default to global in that case.
  final String? characterSeries;

  /// The built-in enum that's currently selected, or null when a
  /// custom row is selected instead.
  final CharacterStatus? builtIn;

  /// The custom-status row id that's currently selected, or null when
  /// a built-in is selected.
  final int? customId;

  final List<CustomStatus> customs;
  final void Function(CharacterStatus) onPickBuiltIn;
  final void Function(int) onPickCustom;

  /// Called after the user creates a brand new custom status — the
  /// caller should select it (typically by setting [customId] to the
  /// returned id).
  final void Function(int) onCreatedCustom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final s in CharacterStatus.values)
          _StatusChip(
            label: builtInStatusLabel(s),
            color: builtInStatusColor(s),
            selected: builtIn == s,
            onSelected: () => onPickBuiltIn(s),
          ),
        for (final c in customs)
          _StatusChip(
            label: c.name,
            color: Color(c.colorArgb),
            selected: customId == c.id,
            onSelected: () => onPickCustom(c.id!),
          ),
        ActionChip(
          avatar: const Icon(Icons.add, size: 16),
          label: const Text('New status'),
          onPressed: () async {
            final id = await showCreateCustomStatusSheet(
              context,
              ref,
              defaultSeries: characterSeries,
            );
            if (id != null) onCreatedCustom(id);
          },
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

/// Shows the "create a custom status" sheet and persists it. Returns
/// the new row's id, or null if the user cancelled.
Future<int?> showCreateCustomStatusSheet(
  BuildContext context,
  WidgetRef ref, {
  String? defaultSeries,
}) async {
  final picked = await showModalBottomSheet<CustomStatusEdit>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _CreateCustomStatusSheet(initialSeries: defaultSeries),
    ),
  );
  if (picked == null) return null;
  final id = await ref.read(characterRepositoryProvider).createCustomStatus(
        name: picked.name,
        colorArgb: picked.colorArgb,
        series: picked.series,
      );
  ref.read(characterRevisionProvider.notifier).state++;
  return id;
}

/// Shows the same sheet pre-filled for editing — returns the new
/// values without persisting (the manage screen handles the update).
Future<CustomStatusEdit?> showEditCustomStatusSheet(
  BuildContext context, {
  required String initialName,
  required int initialColorArgb,
  String? initialSeries,
}) {
  return showModalBottomSheet<CustomStatusEdit>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _CreateCustomStatusSheet(
        initialName: initialName,
        initialColorArgb: initialColorArgb,
        initialSeries: initialSeries,
        editing: true,
      ),
    ),
  );
}

/// Result returned by [_CreateCustomStatusSheet] for both create and
/// edit modes. Public so the manage screen can consume it.
class CustomStatusEdit {
  const CustomStatusEdit({
    required this.name,
    required this.colorArgb,
    this.series,
  });
  final String name;
  final int colorArgb;
  final String? series;
}

/// The 12-color palette for custom statuses. Picked to be bright
/// enough on both light and dark backgrounds without overlapping the
/// existing built-ins.
const List<int> _customStatusPalette = [
  0xFF1565C0, // blue
  0xFF6A1B9A, // purple
  0xFFAD1457, // pink
  0xFFEF6C00, // orange
  0xFFF9A825, // amber
  0xFF558B2F, // lime green
  0xFF2E7D32, // green
  0xFF00838F, // teal
  0xFF4527A0, // deep purple
  0xFFC62828, // red
  0xFF424242, // grey
  0xFF6D4C41, // brown
];

class _CreateCustomStatusSheet extends StatefulWidget {
  const _CreateCustomStatusSheet({
    this.initialName,
    this.initialColorArgb,
    this.initialSeries,
    this.editing = false,
  });

  final String? initialName;
  final int? initialColorArgb;
  final String? initialSeries;
  final bool editing;

  @override
  State<_CreateCustomStatusSheet> createState() =>
      _CreateCustomStatusSheetState();
}

class _CreateCustomStatusSheetState extends State<_CreateCustomStatusSheet> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.initialName ?? '');
  late int _colorArgb =
      widget.initialColorArgb ?? _customStatusPalette.first;
  late String? _series = widget.initialSeries;
  late final Future<List<String>> _seriesOptions = _loadSeries();

  Future<List<String>> _loadSeries() async {
    final all = await BookRepository().getAll();
    final set = <String>{};
    for (final b in all) {
      final s = b.series?.trim();
      if (s != null && s.isNotEmpty) set.add(s);
    }
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    // Make sure the initial value is in the list even if no book uses
    // it yet (e.g. user created one for an unloaded series).
    final initial = widget.initialSeries;
    if (initial != null && !list.contains(initial)) list.add(initial);
    return list;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.editing ? 'Edit status' : 'New status',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Imprisoned, Cursed, Possessed',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<String>>(
              future: _seriesOptions,
              builder: (_, snap) {
                final options = snap.data ?? const <String>[];
                return DropdownButtonFormField<String?>(
                  initialValue: _series,
                  decoration: const InputDecoration(
                    labelText: 'Scope',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Global — every character'),
                    ),
                    for (final s in options)
                      DropdownMenuItem<String?>(
                        value: s,
                        child: Text(
                          s,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _series = v),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Color',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final argb in _customStatusPalette)
                  GestureDetector(
                    onTap: () => setState(() => _colorArgb = argb),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(argb),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _colorArgb == argb
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final name = _nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(
                      context,
                      CustomStatusEdit(
                        name: name,
                        colorArgb: _colorArgb,
                        series: _series,
                      ),
                    );
                  },
                  child: Text(widget.editing ? 'Save' : 'Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
