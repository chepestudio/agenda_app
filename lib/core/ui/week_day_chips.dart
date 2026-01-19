import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WeekDayChips extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;
  final DateTime? anchorDate; // por defecto selectedDate

  const WeekDayChips({
    super.key,
    required this.selectedDate,
    required this.onSelected,
    this.anchorDate,
  });

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _startOfWeek(DateTime d) {
    final onlyDate = DateTime(d.year, d.month, d.day);
    return onlyDate.subtract(Duration(days: onlyDate.weekday - 1)); // lunes
  }

  List<DateTime> _weekDays(DateTime anchor) {
    final start = _startOfWeek(anchor);
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  String _chipLabel(DateTime d) {
    final wd = DateFormat('EEE', 'es').format(d).replaceAll('.', '');
    final day = DateFormat('d', 'es').format(d);
    return '$wd $day';
  }

  @override
  Widget build(BuildContext context) {
    final week = _weekDays(anchorDate ?? selectedDate);

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: week.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = week[i];
          final selected = _isSameDay(d, selectedDate);

          return ChoiceChip(
            label: Text(_chipLabel(d)),
            selected: selected,
            onSelected: (_) => onSelected(d),
          );
        },
      ),
    );
  }
}
