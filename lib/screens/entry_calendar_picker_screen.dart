import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../data/mood_colors.dart';
import '../models/entry.dart';

/// Neutral gray for past days with no entry — distinct from any mood color
/// (including the "bad mood" red) so a gap never reads as a logged crisis.
const Color _missingDayColor = Color(0xFF9E9E9E);

/// Full-month calendar for picking which day to fill in, with a visual cue
/// for past days that have no entry yet — so gaps are easy to spot instead
/// of having to remember or scroll through history.
class EntryCalendarPickerScreen extends StatefulWidget {
  final DateTime initialDate;

  const EntryCalendarPickerScreen({super.key, required this.initialDate});

  @override
  State<EntryCalendarPickerScreen> createState() =>
      _EntryCalendarPickerScreenState();
}

class _EntryCalendarPickerScreenState
    extends State<EntryCalendarPickerScreen> {
  static final DateTime _firstDate = DateTime(2020, 1, 1);
  static const _weekdayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  late DateTime _visibleMonth;
  Map<String, List<MoodEntry>> _entriesByDate = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
    );
    _load();
  }

  Future<void> _load() async {
    final entries = await AppDatabase.instance.allEntries();
    final byDate = <String, List<MoodEntry>>{};
    for (final e in entries) {
      byDate.putIfAbsent(e.dateStr, () => []).add(e);
    }
    setState(() {
      _entriesByDate = byDate;
      _loading = false;
    });
  }

  int _monthIndex(DateTime d) => d.year * 12 + d.month;

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final canGoNext = _monthIndex(_visibleMonth) < _monthIndex(today);
    final canGoPrev = _monthIndex(_visibleMonth) > _monthIndex(_firstDate);

    return Scaffold(
      appBar: AppBar(title: const Text('Choisir une date')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: canGoPrev ? () => _changeMonth(-1) : null,
                      ),
                      Text(
                        _capitalize(
                          DateFormat(
                            'MMMM yyyy',
                            'fr_FR',
                          ).format(_visibleMonth),
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: canGoNext ? () => _changeMonth(1) : null,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      for (final label in _weekdayLabels)
                        Expanded(
                          child: Center(
                            child: Text(
                              label,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(child: _buildGrid(context, today)),
                _buildLegend(context),
              ],
            ),
    );
  }

  Widget _buildGrid(BuildContext context, DateTime today) {
    final year = _visibleMonth.year;
    final month = _visibleMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday; // 1=Mon..7=Sun
    final leadingBlanks = firstWeekday - 1;
    final rows = ((leadingBlanks + daysInMonth) / 7).ceil();

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
      ),
      itemCount: rows * 7,
      itemBuilder: (context, index) {
        final dayNum = index - leadingBlanks + 1;
        if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox.shrink();
        final date = DateTime(year, month, dayNum);
        return _DayCell(
          date: date,
          entries: _entriesByDate[MoodEntry.dateKey(date)] ?? const [],
          isToday: date == today,
          isSelectable: !date.isBefore(_firstDate) && !date.isAfter(today),
          onTap: () => Navigator.pop(context, date),
        );
      },
    );
  }

  Widget _buildLegend(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 4,
        children: [
          _legendDot(context, MoodColors.colorFor(3), 'Jour rempli'),
          _legendDot(context, _missingDayColor, 'Jour manquant'),
        ],
      ),
    );
  }

  Widget _legendDot(BuildContext context, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final List<MoodEntry> entries;
  final bool isToday;
  final bool isSelectable;
  final VoidCallback onTap;

  const _DayCell({
    required this.date,
    required this.entries,
    required this.isToday,
    required this.isSelectable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Color? background;
    Color textColor = colorScheme.onSurface;
    if (entries.isNotEmpty) {
      final avgMood =
          (entries.map((e) => e.mood).reduce((a, b) => a + b) /
                  entries.length)
              .round();
      background = MoodColors.colorFor(avgMood);
      textColor = Colors.white;
    } else if (isSelectable) {
      background = _missingDayColor;
      textColor = Colors.white;
    } else {
      textColor = colorScheme.onSurface.withValues(alpha: 0.3);
    }

    return InkResponse(
      onTap: isSelectable ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
                border: isToday
                    ? Border.all(color: colorScheme.primary, width: 2)
                    : null,
              ),
              alignment: Alignment.center,
              child: Text('${date.day}', style: TextStyle(color: textColor)),
            ),
            if (entries.length > 1)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: colorScheme.secondary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${entries.length}',
                    style: TextStyle(
                      color: colorScheme.onSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
