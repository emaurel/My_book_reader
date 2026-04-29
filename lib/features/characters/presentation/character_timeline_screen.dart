import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/domain/book.dart';
import '../../library/providers/library_provider.dart';
import '../domain/character.dart';
import '../providers/character_provider.dart';
import '../services/character_timeline_service.dart';

class CharacterTimelineScreen extends ConsumerStatefulWidget {
  const CharacterTimelineScreen({super.key, required this.character});

  final Character character;

  @override
  ConsumerState<CharacterTimelineScreen> createState() =>
      _CharacterTimelineScreenState();
}

class _CharacterTimelineScreenState
    extends ConsumerState<CharacterTimelineScreen> {
  int? _selectedBookId;
  Future<List<TimelinePoint>>? _future;
  // Cached so build() doesn't generate a fresh Future on every paint.
  // Without this, FutureBuilder re-resolves with new Book instances
  // and the DropdownButtonFormField loses its selection state.
  late final Future<List<Book>> _booksFuture = _seriesBooks();

  Future<List<Book>> _seriesBooks() async {
    final repo = ref.read(bookRepositoryProvider);
    final all = await repo.getAll();
    final series = widget.character.series;
    if (series == null) {
      return all.where((b) => b.format == BookFormat.epub).toList();
    }
    final list = all
        .where((b) =>
            b.format == BookFormat.epub &&
            b.series != null &&
            b.series!.toLowerCase() == series.toLowerCase())
        .toList();
    list.sort((a, b) {
      final an = a.seriesNumber;
      final bn = b.seriesNumber;
      if (an != null && bn != null) return an.compareTo(bn);
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return list;
  }

  void _runFor(Book book) {
    setState(() {
      _selectedBookId = book.id;
      _future = CharacterTimelineService(
        ref.read(characterRepositoryProvider),
      ).compute(characterId: widget.character.id!, book: book);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.character.name} — timeline'),
      ),
      body: SafeArea(
        child: FutureBuilder<List<Book>>(
          future: _booksFuture,
          builder: (_, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final books = snap.data!;
            if (books.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No EPUB books found in this character\'s series.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            // Auto-pick the first book on first build.
            if (_selectedBookId == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _selectedBookId == null) _runFor(books.first);
              });
            }
            // Compare by id, not identity, so the dropdown holds
            // its selection across rebuilds even if the underlying
            // book list rebuilds with new instances.
            final currentValue = _selectedBookId != null &&
                    books.any((b) => b.id == _selectedBookId)
                ? _selectedBookId
                : null;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: currentValue,
                    decoration: const InputDecoration(
                      labelText: 'Book',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final b in books)
                        DropdownMenuItem(
                          value: b.id,
                          child: Text(
                            b.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) {
                      if (id == null) return;
                      final picked = books.firstWhere((b) => b.id == id);
                      _runFor(picked);
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _buildChart()),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildChart() {
    if (_future == null) return const SizedBox.shrink();
    return FutureBuilder<List<TimelinePoint>>(
      future: _future,
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final points = snap.data!;
        if (points.isEmpty) {
          return const Center(
            child: Text(
              'Timeline available for EPUB only.',
            ),
          );
        }
        final total = points.fold<int>(0, (s, p) => s + p.mentions);
        if (total == 0) {
          return Center(
            child: Text(
              '${widget.character.name} is not mentioned in this book.',
              textAlign: TextAlign.center,
            ),
          );
        }
        final theme = Theme.of(context);
        final maxMentions =
            points.fold<int>(0, (m, p) => p.mentions > m ? p.mentions : m);
        final yMax = (maxMentions * 1.2).clamp(1, 99999).toDouble();
        return BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: yMax,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: theme.colorScheme.outlineVariant,
                strokeWidth: 0.6,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (v, _) => Text(
                    v.toInt().toString(),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= points.length) {
                      return const SizedBox.shrink();
                    }
                    // Sparse labels — every 5 chapters.
                    if (i % 5 != 0 && i != points.length - 1) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        (i + 1).toString(),
                        style: theme.textTheme.bodySmall,
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < points.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: points[i].mentions.toDouble(),
                      width: 5,
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ],
                ),
            ],
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, _, rod, __) {
                  final p = points[group.x];
                  return BarTooltipItem(
                    '${p.chapterTitle}\n${p.mentions} mention'
                    '${p.mentions == 1 ? '' : 's'}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
