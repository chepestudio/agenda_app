import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WeekDayBubbles extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelect;
  final DateTime? anchorDate; // si no lo pasás, usa selectedDate como ancla

  const WeekDayBubbles({
    super.key,
    required this.selectedDate,
    required this.onSelect,
    this.anchorDate,
  });

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  List<DateTime> _weekDates(DateTime base) {
    // semana “móvil” de 7 días empezando hoy (estilo Calendly),
    // no ISO-week (lunes-domingo). Mucho más cómodo.
    final start = _startOfDay(base);
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final base = anchorDate ?? selectedDate;
    final days = _weekDates(base);

    final dfDow = DateFormat('EEE', 'es'); // lun, mar...
    final dfDay = DateFormat('d', 'es');   // 15, 16...

    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: days.length,
        itemBuilder: (context, i) {
          final d = days[i];
          final isSelected = _startOfDay(d) == _startOfDay(selectedDate);

          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onSelect(d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black12,
                  width: isSelected ? 2 : 1,
                ),
                color: isSelected
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.10)
                    : Colors.white,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dfDow.format(d).toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dfDay.format(d),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
