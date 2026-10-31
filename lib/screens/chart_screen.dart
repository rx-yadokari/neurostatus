import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/contacts_repository.dart';
import '../data/database.dart';
import '../data/emotions_repository.dart';
import '../data/mood_colors.dart';
import '../data/series_colors.dart';
import '../models/entry.dart';

const _overlayPrefsKey = 'chart_overlay_series';
// Superseded by _overlayPrefsKey when contacts were added to the overlay;
// read once to migrate anyone's existing emotion selection forward.
const _legacyOverlayPrefsKey = 'chart_overlay_emotions';
const _minRunLength = 1;

enum _ChartGranularity { day, week }

class _WeekBucket {
  final DateTime start;
  final double avgMood;
  final int count;

  _WeekBucket({
    required this.start,
    required this.avgMood,
    required this.count,
  });
}

class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  static const double _minDayWidth = 10;
  static const double _maxDayWidth = 96;

  List<MoodEntry> _entries = [];
  List<String> _allEmotions = [];
  List<String> _allContacts = [];
  Set<String> _overlaySeries = {};
  Map<String, int> _crisisCounts = {};
  bool _loading = true;
  double _dayWidth = 56;
  _ChartGranularity _granularity = _ChartGranularity.day;

  /// Combined, stably-ordered catalog used for color assignment so an
  /// emotion and a contact never end up sharing a color.
  List<String> get _seriesCatalog => [..._allEmotions, ..._allContacts];

  bool _hasSeries(MoodEntry entry, String name) =>
      entry.emotions.contains(name) || entry.contacts.contains(name);

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _load();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _load() async {
    final entries = await AppDatabase.instance.allEntries(descending: false);
    final emotions = await EmotionsRepository.instance.allEmotions();
    final contacts = await ContactsRepository.instance.allContacts();
    final crisisLogs = await AppDatabase.instance.allCrisisLogs();
    final prefs = await SharedPreferences.getInstance();
    final currentSaved = prefs.getStringList(_overlayPrefsKey);
    final legacySaved = currentSaved == null
        ? prefs.getStringList(_legacyOverlayPrefsKey)
        : null;
    if (legacySaved != null) {
      await prefs.setStringList(_overlayPrefsKey, legacySaved);
      await prefs.remove(_legacyOverlayPrefsKey);
    }
    final saved = currentSaved ?? legacySaved ?? <String>[];
    final catalog = {...emotions, ...contacts};
    final crisisCounts = <String, int>{};
    for (final log in crisisLogs) {
      crisisCounts[log.dateStr] = (crisisCounts[log.dateStr] ?? 0) + 1;
    }
    setState(() {
      _entries = entries;
      _allEmotions = emotions;
      _allContacts = contacts;
      _overlaySeries = saved.where(catalog.contains).toSet();
      _crisisCounts = crisisCounts;
      _loading = false;
    });
  }

  Future<void> _setOverlaySeries(Set<String> series) async {
    setState(() => _overlaySeries = series);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_overlayPrefsKey, series.toList());
  }

  /// Runs (start/end index inclusive) of _minRunLength+ consecutive entries
  /// where [name] (an emotion or a contact) was recorded.
  List<(int, int)> _runsFor(String name) {
    final runs = <(int, int)>[];
    int? start;
    for (var i = 0; i < _entries.length; i++) {
      if (_hasSeries(_entries[i], name)) {
        start ??= i;
      } else if (start != null) {
        if (i - start >= _minRunLength) runs.add((start, i - 1));
        start = null;
      }
    }
    if (start != null && _entries.length - start >= _minRunLength) {
      runs.add((start, _entries.length - 1));
    }
    return runs;
  }

  Widget _seriesChipWrap({
    required List<String> names,
    required Set<String> selection,
    required void Function(String name, bool selected) onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final name in names)
          FilterChip(
            label: Text(name),
            selected: selection.contains(name),
            avatar: selection.contains(name)
                ? CircleAvatar(
                    backgroundColor: SeriesColors.colorFor(
                      _seriesCatalog.indexOf(name),
                      Theme.of(context).brightness,
                    ),
                  )
                : null,
            onSelected: (selected) {
              if (selected && selection.length >= SeriesColors.maxSeries) {
                return;
              }
              onSelected(name, selected);
            },
          ),
      ],
    );
  }

  Future<void> _pickOverlaySeries() async {
    var selection = {..._overlaySeries};
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void toggle(String name, bool selected) {
              setSheetState(() {
                if (selected) {
                  selection.add(name);
                } else {
                  selection.remove(name);
                }
              });
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Suivre des émotions ou des contacts sur le graphique',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Une bande apparaît sous le graphique les jours où '
                      'c\'est coché (max ${SeriesColors.maxSeries}).',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.5,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Émotions',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            _seriesChipWrap(
                              names: _allEmotions,
                              selection: selection,
                              onSelected: toggle,
                            ),
                            if (_allContacts.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Contacts sociaux',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 8),
                              _seriesChipWrap(
                                names: _allContacts,
                                selection: selection,
                                onSelected: toggle,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, selection),
                        child: const Text('OK'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (result != null) await _setOverlaySeries(result);
  }

  List<_WeekBucket> _weeklyBuckets() {
    final map = <DateTime, List<int>>{};
    for (final e in _entries) {
      final monday = e.date.subtract(Duration(days: e.date.weekday - 1));
      final key = DateTime(monday.year, monday.month, monday.day);
      map.putIfAbsent(key, () => []).add(e.mood);
    }
    final keys = map.keys.toList()..sort();
    return [
      for (final k in keys)
        _WeekBucket(
          start: k,
          avgMood: map[k]!.reduce((a, b) => a + b) / map[k]!.length,
          count: map[k]!.length,
        ),
    ];
  }

  void _zoom(double factor) {
    setState(() {
      _dayWidth = (_dayWidth * factor).clamp(_minDayWidth, _maxDayWidth);
    });
  }

  void _fitAll() {
    final count = _granularity == _ChartGranularity.day
        ? _entries.length
        : _weeklyBuckets().length;
    if (count < 2) return;
    final available = MediaQuery.of(context).size.width - 32;
    setState(() {
      _dayWidth = (available / count).clamp(_minDayWidth, _maxDayWidth);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Évolution'),
        actions: _entries.length < 2
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.timeline),
                  tooltip: 'Suivre des émotions ou des contacts',
                  onPressed: _pickOverlaySeries,
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_out),
                  tooltip: 'Dézoomer',
                  onPressed: () => _zoom(1 / 1.4),
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_in),
                  tooltip: 'Zoomer',
                  onPressed: () => _zoom(1.4),
                ),
                IconButton(
                  icon: const Icon(Icons.fit_screen),
                  tooltip: 'Tout afficher',
                  onPressed: _fitAll,
                ),
              ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _entries.length < 2
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Pas encore assez de données. Reviens après quelques jours de suivi.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : Column(
                children: [
                  _buildGranularityToggle(),
                  Expanded(
                    child: _granularity == _ChartGranularity.day
                        ? _buildChart()
                        : _buildWeeklyChart(),
                  ),
                  if (_granularity == _ChartGranularity.day &&
                      _overlaySeries.isNotEmpty)
                    _buildOverlayLegend(),
                  _buildLegend(),
                ],
              ),
      ),
    );
  }

  Widget _buildGranularityToggle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: SegmentedButton<_ChartGranularity>(
        segments: const [
          ButtonSegment(
            value: _ChartGranularity.day,
            label: Text('Jour'),
            icon: Icon(Icons.calendar_view_day),
          ),
          ButtonSegment(
            value: _ChartGranularity.week,
            label: Text('Semaine'),
            icon: Icon(Icons.calendar_view_week),
          ),
        ],
        selected: {_granularity},
        onSelectionChanged: (selection) {
          setState(() => _granularity = selection.first);
        },
      ),
    );
  }

  Widget _buildOverlayLegend() {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final name in _overlaySeries)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: SeriesColors.colorFor(
                      _seriesCatalog.indexOf(name),
                      brightness,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(name, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: [
          const Text('Humeur : '),
          for (final score in MoodColors.legend)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: MoodColors.colorFor(score),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$score',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star,
                  size: 14,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'évènement marquant',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (_crisisCounts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error,
                    size: 14,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'crise signalée',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final chartWidth = (_entries.length * _dayWidth).clamp(
      MediaQuery.of(context).size.width,
      double.infinity,
    );
    final barWidth = (_dayWidth * 0.6).clamp(2.0, 40.0);
    final markerSize = (_dayWidth * 0.3).clamp(10.0, 16.0);

    // Month boundaries: full segments for alternating background bands
    // (fl_chart's BarChart ignores vertical extra-lines, so a subtle band
    // is used instead of a divider line), and a thinned set of first-day
    // indices for the text labels so they never crowd when zoomed out.
    final monthSegments = <(int, int)>[];
    var segStart = 0;
    for (var i = 1; i <= _entries.length; i++) {
      final isBoundary =
          i == _entries.length ||
          _entries[i].date.month != _entries[i - 1].date.month ||
          _entries[i].date.year != _entries[i - 1].date.year;
      if (isBoundary) {
        monthSegments.add((segStart, i - 1));
        segStart = i;
      }
    }
    final monthLabelIndices = <int>{};
    final minIndexGap = (40 / _dayWidth).ceil().clamp(1, 1000);
    int? lastLabelIndex;
    for (final (start, _) in monthSegments) {
      if (lastLabelIndex == null || start - lastLabelIndex >= minIndexGap) {
        monthLabelIndices.add(start);
        lastLabelIndex = start;
      }
    }

    final bandColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.045);
    final brightness = Theme.of(context).brightness;

    final groups = [
      for (var i = 0; i < _entries.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: _entries[i].mood.toDouble(),
              width: barWidth,
              color: MoodColors.colorFor(_entries[i].mood),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(3),
                topRight: Radius.circular(3),
              ),
            ),
          ],
        ),
    ];

    const stripHeight = 8.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(8, 8, 24, 16),
      child: SizedBox(
        width: chartWidth,
        child: Column(
          children: [
            Expanded(
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: 5,
                  alignment: BarChartAlignment.spaceBetween,
                  gridData: FlGridData(
                    horizontalInterval: 1,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  rangeAnnotations: RangeAnnotations(
                    verticalRangeAnnotations: [
                      for (var m = 0; m < monthSegments.length; m += 2)
                        VerticalRangeAnnotation(
                          x1: monthSegments[m].$1 - 0.5,
                          x2: monthSegments[m].$2 + 0.5,
                          color: bandColor,
                        ),
                    ],
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          if (value > 5) return const SizedBox.shrink();
                          return Text(value.toInt().toString());
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final i = value.round();
                          if (i < 0 ||
                              i >= _entries.length ||
                              !monthLabelIndices.contains(i)) {
                            return const SizedBox.shrink();
                          }
                          final label = DateFormat(
                            'MMM',
                            'fr_FR',
                          ).format(_entries[i].date);
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              label[0].toUpperCase() + label.substring(1),
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final entry = _entries[group.x];
                        final emotions = entry.emotions.isEmpty
                            ? ''
                            : '\n${entry.emotions.join(', ')}';
                        final contacts = entry.contacts.isEmpty
                            ? ''
                            : '\n👥 ${entry.contacts.join(', ')}';
                        final event =
                            entry.event == null || entry.event!.isEmpty
                            ? ''
                            : '\n★ ${entry.event}';
                        final crisisCount = _crisisCounts[entry.dateStr] ?? 0;
                        final crisis = crisisCount == 0
                            ? ''
                            : '\n⚠ $crisisCount crise${crisisCount > 1 ? 's' : ''}';
                        return BarTooltipItem(
                          '${DateFormat('d MMM · HH:mm', 'fr_FR').format(entry.timestamp)} · ${entry.mood}/5$emotions$contacts$event$crisis',
                          const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  barGroups: groups,
                ),
              ),
            ),
            SizedBox(
              width: chartWidth,
              height: markerSize + 6,
              child: Row(
                children: [
                  for (final entry in _entries)
                    SizedBox(
                      width: _dayWidth,
                      child: (entry.event == null || entry.event!.isEmpty)
                          ? null
                          : Center(
                              child: Icon(
                                Icons.star,
                                size: markerSize,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                    ),
                ],
              ),
            ),
            if (_crisisCounts.isNotEmpty)
              SizedBox(
                width: chartWidth,
                height: markerSize + 6,
                child: Row(
                  children: [
                    for (final entry in _entries)
                      SizedBox(
                        width: _dayWidth,
                        child: (_crisisCounts[entry.dateStr] ?? 0) == 0
                            ? null
                            : Center(
                                child: Icon(
                                  Icons.error,
                                  size: markerSize,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                      ),
                  ],
                ),
              ),
            for (final name in _overlaySeries)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SizedBox(
                  height: stripHeight,
                  width: chartWidth,
                  child: CustomPaint(
                    painter: _PresenceStripPainter(
                      runs: _runsFor(name),
                      dayWidth: _dayWidth,
                      color: SeriesColors.colorFor(
                        _seriesCatalog.indexOf(name),
                        brightness,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyChart() {
    final buckets = _weeklyBuckets();
    if (buckets.length < 2) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Pas encore assez de semaines suivies pour cette vue.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final chartWidth = (buckets.length * _dayWidth).clamp(
      MediaQuery.of(context).size.width,
      double.infinity,
    );
    final barWidth = (_dayWidth * 0.6).clamp(2.0, 40.0);

    final monthSegments = <(int, int)>[];
    var segStart = 0;
    for (var i = 1; i <= buckets.length; i++) {
      final isBoundary =
          i == buckets.length ||
          buckets[i].start.month != buckets[i - 1].start.month ||
          buckets[i].start.year != buckets[i - 1].start.year;
      if (isBoundary) {
        monthSegments.add((segStart, i - 1));
        segStart = i;
      }
    }
    final monthLabelIndices = <int>{};
    final minIndexGap = (40 / _dayWidth).ceil().clamp(1, 1000);
    int? lastLabelIndex;
    for (final (start, _) in monthSegments) {
      if (lastLabelIndex == null || start - lastLabelIndex >= minIndexGap) {
        monthLabelIndices.add(start);
        lastLabelIndex = start;
      }
    }

    final bandColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.045);

    final groups = [
      for (var i = 0; i < buckets.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: buckets[i].avgMood,
              width: barWidth,
              color: MoodColors.colorFor(buckets[i].avgMood.round()),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(3),
                topRight: Radius.circular(3),
              ),
            ),
          ],
        ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(8, 8, 24, 16),
      child: SizedBox(
        width: chartWidth,
        child: BarChart(
          BarChartData(
            minY: 0,
            maxY: 5,
            alignment: BarChartAlignment.spaceBetween,
            gridData: FlGridData(
              horizontalInterval: 1,
              drawVerticalLine: false,
            ),
            borderData: FlBorderData(show: false),
            rangeAnnotations: RangeAnnotations(
              verticalRangeAnnotations: [
                for (var m = 0; m < monthSegments.length; m += 2)
                  VerticalRangeAnnotation(
                    x1: monthSegments[m].$1 - 0.5,
                    x2: monthSegments[m].$2 + 0.5,
                    color: bandColor,
                  ),
              ],
            ),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    if (value > 5) return const SizedBox.shrink();
                    return Text(value.toInt().toString());
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final i = value.round();
                    if (i < 0 ||
                        i >= buckets.length ||
                        !monthLabelIndices.contains(i)) {
                      return const SizedBox.shrink();
                    }
                    final label = DateFormat(
                      'MMM',
                      'fr_FR',
                    ).format(buckets[i].start);
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        label[0].toUpperCase() + label.substring(1),
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final bucket = buckets[group.x];
                  final weekEnd = bucket.start.add(const Duration(days: 6));
                  return BarTooltipItem(
                    '${DateFormat('d MMM', 'fr_FR').format(bucket.start)} - '
                    '${DateFormat('d MMM', 'fr_FR').format(weekEnd)}\n'
                    '${bucket.avgMood.toStringAsFixed(1)}/5 moyenne '
                    '(${bucket.count} jour${bucket.count > 1 ? 's' : ''} suivis)',
                    const TextStyle(color: Colors.white),
                  );
                },
              ),
            ),
            barGroups: groups,
          ),
        ),
      ),
    );
  }
}

class _PresenceStripPainter extends CustomPainter {
  final List<(int, int)> runs;
  final double dayWidth;
  final Color color;

  _PresenceStripPainter({
    required this.runs,
    required this.dayWidth,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final (start, end) in runs) {
      final rect = Rect.fromLTRB(
        start * dayWidth + dayWidth * 0.1,
        0,
        (end + 1) * dayWidth - dayWidth * 0.1,
        size.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PresenceStripPainter oldDelegate) =>
      oldDelegate.runs != runs ||
      oldDelegate.dayWidth != dayWidth ||
      oldDelegate.color != color;
}
