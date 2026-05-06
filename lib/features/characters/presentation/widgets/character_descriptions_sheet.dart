import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../library/providers/library_provider.dart';
import '../../domain/character.dart';
import '../../domain/character_description.dart';
import '../../providers/character_provider.dart';
import '../../services/spoiler_position.dart';
import 'character_affiliations_editor.dart';
import 'character_alias_editor.dart';
import 'character_description_card.dart';
import 'character_status_editor.dart';

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
  int? currentPageInChapter,
}) {
  // Cap the sheet at 80% of the screen so a character with a lot of
  // descriptions / relationships doesn't open as a full-screen takeover
  // that the user has to scroll back down before they can dismiss it.
  final maxH = MediaQuery.of(context).size.height * 0.8;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: BoxConstraints(maxHeight: maxH),
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
        currentPageInChapter: currentPageInChapter,
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
    this.currentPageInChapter,
  });
  final String tappedName;
  final int? characterId;
  final String? bookSeries;
  final int? currentBookId;
  final int? currentChapterIndex;
  final int? currentPageInChapter;

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
              currentPageInChapter: currentPageInChapter,
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
    this.currentPageInChapter,
  });
  final Character character;
  final int? currentBookId;
  final int? currentChapterIndex;
  final int? currentPageInChapter;

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
        _SpoilerAwareStatusRow(
          character: widget.character,
          currentBookId: widget.currentBookId,
          currentChapterIndex: widget.currentChapterIndex,
          currentPageInChapter: widget.currentPageInChapter,
        ),
        const Divider(),
        CharacterAliasEditor(character: widget.character),
        const SizedBox(height: 12),
        CharacterAffiliationsEditor(character: widget.character),
        const SizedBox(height: 16),
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
              currentPageInChapter: widget.currentPageInChapter,
              revealAll: _revealSpoilers,
              onRevealAll: () => setState(() => _revealSpoilers = true),
            );
          },
        ),
      ],
    );
  }
}

/// Thin pass-through to [CharacterStatusEditor]. The editor now does
/// its own resolved-status rendering using the reader-position
/// provider, so the wrapper's only role left is to forward the
/// (book, chapter, page) defaults the in-reader sheet was given.
class _SpoilerAwareStatusRow extends StatelessWidget {
  const _SpoilerAwareStatusRow({
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
  Widget build(BuildContext context) {
    return CharacterStatusEditor(
      character: character,
      currentBookId: currentBookId,
      currentChapterIndex: currentChapterIndex,
      currentPageInChapter: currentPageInChapter,
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
    this.currentPageInChapter,
  });

  final List<CharacterDescription> all;
  final bool revealAll;
  final VoidCallback onRevealAll;
  final int? currentBookId;
  final int? currentChapterIndex;
  final int? currentPageInChapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (currentBookId == null) {
      return _list(all);
    }
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
    final position = ReaderPosition(
      bookId: currentBookId!,
      chapterIndex: currentChapterIndex ?? 0,
      pageInChapter: currentPageInChapter ?? 0,
      series: currentBook?.series,
      seriesNumber: currentBook?.seriesNumber,
    );
    final cache = BookMetadataCache(repo);
    final result = <bool>[];
    for (final d in all) {
      final anchor = await cache.hydrate(
        bookId: d.spoilerBookId,
        chapterIndex: d.spoilerChapterIndex,
        pageInChapter: d.spoilerPageInChapter,
      );
      final order = compareAnchor(anchor, position);
      result.add(order == AnchorOrder.ahead);
    }
    return result;
  }
}
