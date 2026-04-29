import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../library/data/book_repository.dart';
import '../../../library/providers/library_provider.dart';
import '../../domain/character.dart';
import '../../domain/character_description.dart';
import '../../providers/character_provider.dart';
import '../character_timeline_screen.dart';
import 'character_affiliations_editor.dart';
import 'character_alias_editor.dart';
import 'character_description_card.dart';

/// Sheet shown when an underlined character name is tapped. Lists every
/// saved description for that character; lets the user manage aliases
/// and edit/delete each description inline.
///
/// When [currentBookId] / [currentChapterIndex] are set, descriptions
/// whose spoiler-anchor is *ahead* of that position are hidden behind
/// a "spoilers ahead" toggle. Outside the reader (Characters screen)
/// these stay null, so everything is visible by default.
Future<void> showCharacterDescriptionsSheet(
  BuildContext context, {
  required String name,
  int? characterId,
  String? bookSeries,
  int? currentBookId,
  int? currentChapterIndex,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetCtx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom,
      ),
      child: _CharacterDescriptionsSheet(
        tappedName: name,
        characterId: characterId,
        bookSeries: bookSeries,
        currentBookId: currentBookId,
        currentChapterIndex: currentChapterIndex,
      ),
    ),
  );
}

class _CharacterDescriptionsSheet extends ConsumerWidget {
  const _CharacterDescriptionsSheet({
    required this.tappedName,
    this.characterId,
    this.bookSeries,
    this.currentBookId,
    this.currentChapterIndex,
  });
  final String tappedName;
  final int? characterId;
  final String? bookSeries;
  final int? currentBookId;
  final int? currentChapterIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fut = _resolveCharacter(ref);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: FutureBuilder<Character?>(
          future: fut,
          builder: (_, snap) {
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final character = snap.data;
            if (character == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tappedName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text('No descriptions for this character.'),
                ],
              );
            }
            return _CharacterBody(
              character: character,
              currentBookId: currentBookId,
              currentChapterIndex: currentChapterIndex,
            );
          },
        ),
      ),
    );
  }

  Future<Character?> _resolveCharacter(WidgetRef ref) async {
    final repo = ref.read(characterRepositoryProvider);
    if (characterId != null) {
      final all = await repo.listAll();
      for (final c in all) {
        if (c.id == characterId) return c;
      }
    }
    return repo.findByNameOrAlias(tappedName, series: bookSeries);
  }
}

class _CharacterBody extends ConsumerStatefulWidget {
  const _CharacterBody({
    required this.character,
    this.currentBookId,
    this.currentChapterIndex,
  });
  final Character character;
  final int? currentBookId;
  final int? currentChapterIndex;

  @override
  ConsumerState<_CharacterBody> createState() => _CharacterBodyState();
}

class _CharacterBodyState extends ConsumerState<_CharacterBody> {
  bool _revealSpoilers = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final descs =
        ref.watch(descriptionsForCharacterProvider(widget.character.id!));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.character.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        CharacterAliasEditor(character: widget.character),
        const SizedBox(height: 12),
        CharacterAffiliationsEditor(character: widget.character),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.timeline),
            label: const Text('View timeline'),
            onPressed: widget.character.id == null
                ? null
                : () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CharacterTimelineScreen(
                          character: widget.character,
                        ),
                      ),
                    );
                  },
          ),
        ),
        const SizedBox(height: 8),
        descs.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Error: $e'),
          data: (list) {
            if (list.isEmpty) {
              return Text(
                'No descriptions saved yet.',
                style: theme.textTheme.bodyMedium,
              );
            }
            return _DescriptionsList(
              all: list,
              currentBookId: widget.currentBookId,
              currentChapterIndex: widget.currentChapterIndex,
              revealAll: _revealSpoilers,
              onRevealAll: () => setState(() => _revealSpoilers = true),
            );
          },
        ),
      ],
    );
  }
}

class _DescriptionsList extends ConsumerWidget {
  const _DescriptionsList({
    required this.all,
    required this.revealAll,
    required this.onRevealAll,
    this.currentBookId,
    this.currentChapterIndex,
  });

  final List<CharacterDescription> all;
  final bool revealAll;
  final VoidCallback onRevealAll;
  final int? currentBookId;
  final int? currentChapterIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // No reader context → show everything.
    if (currentBookId == null) {
      return _list(all);
    }
    // Determine spoiler hits asynchronously so we can compare books'
    // seriesNumber across the user's library.
    return FutureBuilder<List<bool>>(
      future: _classifySpoilers(ref),
      builder: (_, snap) {
        if (!snap.hasData) return _list(all);
        final isHidden = snap.data!;
        final visible = <CharacterDescription>[];
        var hiddenCount = 0;
        for (var i = 0; i < all.length; i++) {
          if (isHidden[i] && !revealAll) {
            hiddenCount++;
          } else {
            visible.add(all[i]);
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _list(visible),
            if (hiddenCount > 0) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: onRevealAll,
                  icon: const Icon(Icons.visibility_off_outlined),
                  label: Text(
                    'Reveal $hiddenCount spoiler'
                    '${hiddenCount == 1 ? '' : 's'} ahead of you',
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _list(List<CharacterDescription> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final d in items)
          CharacterDescriptionCard(
            key: ValueKey(d.id),
            description: d,
          ),
      ],
    );
  }

  Future<List<bool>> _classifySpoilers(WidgetRef ref) async {
    final repo = ref.read(bookRepositoryProvider);
    final currentBook = await repo.getById(currentBookId!);
    final currentSeries = currentBook?.series;
    final currentSeriesNum = currentBook?.seriesNumber;
    final currentChapter = currentChapterIndex ?? 0;

    final result = <bool>[];
    for (final d in all) {
      result.add(await _isSpoiler(
        d,
        repo,
        currentBookId!,
        currentSeries,
        currentSeriesNum,
        currentChapter,
      ));
    }
    return result;
  }

  Future<bool> _isSpoiler(
    CharacterDescription d,
    BookRepository repo,
    int currentBookId,
    String? currentSeries,
    double? currentSeriesNum,
    int currentChapter,
  ) async {
    if (d.spoilerBookId == null && d.spoilerChapterIndex == null) {
      return false;
    }
    if (d.spoilerBookId == currentBookId) {
      // Same book: spoil if the user is BEFORE the spoiler chapter.
      final spoilerCh = d.spoilerChapterIndex;
      if (spoilerCh == null) return false;
      return currentChapter < spoilerCh;
    }
    // Different book: check series order via seriesNumber.
    final spoilerBook = await repo.getById(d.spoilerBookId ?? -1);
    if (spoilerBook == null) return false;
    if (spoilerBook.series == null ||
        spoilerBook.series != currentSeries ||
        spoilerBook.seriesNumber == null ||
        currentSeriesNum == null) {
      // Can't compare across unrelated books — show by default to
      // avoid hiding non-spoiler context that just happens to come
      // from another book.
      return false;
    }
    return spoilerBook.seriesNumber! > currentSeriesNum;
  }
}
