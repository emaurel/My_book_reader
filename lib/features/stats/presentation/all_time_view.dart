import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../library/domain/book.dart';
import '../../library/providers/library_provider.dart';
import '../domain/stats.dart';
import '../providers/stats_provider.dart';

class AllTimeView extends ConsumerWidget {
  const AllTimeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats = ref.watch(allTimeStatsProvider);
    return asyncStats.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (stats) => _AllTimeBody(stats: stats),
    );
  }
}

class _AllTimeBody extends StatefulWidget {
  const _AllTimeBody({required this.stats});

  final AllTimeStats stats;

  @override
  State<_AllTimeBody> createState() => _AllTimeBodyState();
}

class _AllTimeBodyState extends State<_AllTimeBody> {
  late final List<StatsMonth> _months;
  late final PageController _controller;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _months = _buildMonthList(widget.stats.firstActivityAt);
    _currentPage = _months.length - 1; // newest month last → start there
    _controller = PageController(initialPage: _currentPage);
  }

  static List<StatsMonth> _buildMonthList(DateTime? earliest) {
    final now = DateTime.now();
    final start = earliest ?? DateTime(now.year, now.month, 1);
    final list = <StatsMonth>[];
    var y = start.year;
    var m = start.month;
    while (y < now.year || (y == now.year && m <= now.month)) {
      list.add(StatsMonth(y, m));
      m++;
      if (m > 12) {
        m = 1;
        y++;
      }
    }
    return list;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: AppLocalizations.of(context).statsCardPages,
                    value: _fmt(widget.stats.totalPages),
                    caption: AppLocalizations.of(context).statsCaptionAllTime,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: AppLocalizations.of(context).statsCardWords,
                    value: _fmt(widget.stats.totalWords),
                    caption: AppLocalizations.of(context).statsCaptionAllTime,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: AppLocalizations.of(context).statsCardBooks,
                    value: widget.stats.booksFinished.toString(),
                    caption:
                        AppLocalizations.of(context).statsCardBooksFinished,
                    onTap: widget.stats.booksFinished == 0
                        ? null
                        : () => _showFinishedBooks(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentPage > 0
                      ? () => _controller.previousPage(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                          )
                      : null,
                ),
                Text(
                  _monthLabel(_months[_currentPage]),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _currentPage < _months.length - 1
                      ? () => _controller.nextPage(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                          )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _months.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => _MonthChart(month: _months[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  String _monthLabel(StatsMonth m) =>
      '${_monthNames[m.month - 1]} ${m.year}';

  String _fmt(int n) {
    if (n < 1000) return n.toString();
    if (n < 10000) return '${(n / 1000).toStringAsFixed(1)}k';
    if (n < 1000000) return '${(n / 1000).round()}k';
    return '${(n / 1000000).toStringAsFixed(1)}M';
  }

  void _showFinishedBooks(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _FinishedBooksSheet(),
    );
  }
}

class _FinishedBooksSheet extends ConsumerWidget {
  const _FinishedBooksSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.75;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: FutureBuilder<List<Book>>(
          future: ref.read(bookRepositoryProvider).getFinished(),
          builder: (_, snap) {
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final books = snap.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Text(
                    AppLocalizations.of(context).statsFinishedSheetTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    itemCount: books.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => _FinishedBookTile(book: books[i]),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FinishedBookTile extends ConsumerWidget {
  const _FinishedBookTile({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final coverPath = book.coverPath;
    final hasCover = coverPath != null && File(coverPath).existsSync();
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: hasCover
            ? Image.file(
                File(coverPath),
                width: 36,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _Placeholder(),
              )
            : const _Placeholder(),
      ),
      title: Text(
        book.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${book.author ?? '—'} · '
        '${(book.progress * 100).toStringAsFixed(2)}%',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      trailing: book.id == null
          ? null
          : PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'open' && book.id != null) {
                  Navigator.pop(context);
                  context.push('/read/${book.id}');
                } else if (v == 'unmark' && book.id != null) {
                  // Knock progress back to 95% so it leaves the
                  // finished bucket without the user losing their
                  // place — they can pick up where they were.
                  final repo = ref.read(bookRepositoryProvider);
                  await repo.update(book.copyWith(progress: 0.95));
                  ref.invalidate(allTimeStatsProvider);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'open',
                  child: Text(AppLocalizations.of(context).actionOpen),
                ),
                PopupMenuItem(
                  value: 'unmark',
                  child:
                      Text(AppLocalizations.of(context).statsMarkAsNotFinished),
                ),
              ],
            ),
      onTap: book.id == null
          ? null
          : () {
              Navigator.pop(context);
              context.push('/read/${book.id}');
            },
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 50,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(Icons.book_outlined, size: 18),
    );
  }
}

class _MonthChart extends ConsumerWidget {
  const _MonthChart({required this.month});

  final StatsMonth month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBuckets = ref.watch(monthlyChartProvider(month));
    return asyncBuckets.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (buckets) {
        final total = buckets.fold<int>(0, (s, b) => s + b.pages);
        if (total == 0) {
          return Center(
            child: Text(
              'No reading recorded this month.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        return _Bars(buckets: buckets);
      },
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.buckets});

  final List<ReadingBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxPages = buckets.fold<int>(0, (m, b) => b.pages > m ? b.pages : m);
    final yMax = (maxPages == 0 ? 1 : maxPages * 1.2).toDouble();
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
                if (i < 0 ||
                    i >= buckets.length ||
                    buckets[i].label.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    buckets[i].label,
                    style: theme.textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < buckets.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: buckets[i].pages.toDouble(),
                  width: 5,
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.caption,
    this.onTap,
  });

  final String label;
  final String value;
  final String caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            caption,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? body
          : InkWell(onTap: onTap, child: body),
    );
  }
}
