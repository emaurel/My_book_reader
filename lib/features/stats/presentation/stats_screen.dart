import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/navigation/main_drawer.dart';
import '../domain/stats.dart';
import '../providers/stats_provider.dart';
import 'all_time_view.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        drawer: const MainDrawer(currentRoute: '/stats'),
        appBar: AppBar(
          title: const Text('Statistics'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Day'),
              Tab(text: 'Week'),
              Tab(text: 'Month'),
              Tab(text: 'All time'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _StatsTab(range: StatsRange.day),
            _StatsTab(range: StatsRange.week),
            _StatsTab(range: StatsRange.month),
            AllTimeView(),
          ],
        ),
      ),
    );
  }
}

class _StatsTab extends ConsumerWidget {
  const _StatsTab({required this.range});

  final StatsRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats = ref.watch(readingStatsProvider(range));
    return asyncStats.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (stats) => _StatsBody(range: range, stats: stats),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.range, required this.stats});

  final StatsRange range;
  final ReadingStats stats;

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
                  label: 'Pages',
                  value: stats.totalPages.toString(),
                  caption: _captionFor(range),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Words',
                  value: _fmtCount(stats.totalWords),
                  caption: _captionFor(range),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Pages / hour',
                  value: stats.pagesPerHour > 0
                      ? stats.pagesPerHour.toStringAsFixed(0)
                      : '—',
                  caption: 'active reading',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Words / hour',
                  value: stats.wordsPerHour > 0
                      ? _fmtCount(stats.wordsPerHour.round())
                      : '—',
                  caption: 'active reading',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: stats.totalPages == 0
                ? Center(
                    child: Text(
                      'No reading recorded ${_captionFor(range)} yet.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                : _BarChart(
                    buckets: stats.buckets,
                    range: range,
                  ),
          ),
        ],
        ),
      ),
    );
  }

  String _captionFor(StatsRange r) {
    switch (r) {
      case StatsRange.day:
        return 'last 24h';
      case StatsRange.week:
        return 'last 7 days';
      case StatsRange.month:
        return 'last 30 days';
    }
  }

  String _fmtCount(int n) {
    if (n < 1000) return n.toString();
    if (n < 10000) return '${(n / 1000).toStringAsFixed(1)}k';
    if (n < 1000000) return '${(n / 1000).round()}k';
    return '${(n / 1000000).toStringAsFixed(1)}M';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.buckets, required this.range});

  final List<ReadingBucket> buckets;
  final StatsRange range;

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
                if (i < 0 || i >= buckets.length) {
                  return const SizedBox.shrink();
                }
                // Day view: label every 6 hours plus the rightmost
                // bar so the user always sees where "now" is.
                if (range == StatsRange.day &&
                    i % 6 != 0 &&
                    i != buckets.length - 1) {
                  return const SizedBox.shrink();
                }
                if (buckets[i].label.isEmpty) {
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
                  width: _barWidthFor(range),
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
        ],
      ),
    );
  }

  double _barWidthFor(StatsRange r) {
    switch (r) {
      case StatsRange.day:
        return 6;
      case StatsRange.week:
        return 18;
      case StatsRange.month:
        return 5;
    }
  }
}
