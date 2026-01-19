import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'client_form.dart';

class TimeSlotsForDay extends StatelessWidget {
  final String businessId;
  final DateTime date;

  final TimeOfDay? selectedTime; // ✅ NUEVO
  final void Function(TimeOfDay time) onPick;

  const TimeSlotsForDay({
    super.key,
    required this.businessId,
    required this.date,
    required this.onPick,
    this.selectedTime, // ✅ NUEVO
  });

  String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  int _weekdayKey(DateTime d) {
    // DateTime.weekday: 1=lunes ... 7=domingo
    return d.weekday;
  }

  DateTime _combine(DateTime day, String hhmm) {
    final parts = hhmm.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    return DateTime(day.year, day.month, day.day, h, m);
  }

  List<DateTime> _generateSlots({
    required DateTime start,
    required DateTime end,
    required int stepMin,
  }) {
    final slots = <DateTime>[];
    var cur = start;
    while (cur.isBefore(end)) {
      slots.add(cur);
      cur = cur.add(Duration(minutes: stepMin));
    }
    return slots;
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    final settingsRef = db
        .collection('businesses')
        .doc(businessId)
        .collection('settings')
        .doc('main');

    // ✅ Locks del día (incluye locks de citas + bloqueos admin)
    final locksQuery = db
        .collection('businesses')
        .doc(businessId)
        .collection('slot_locks')
        .where('dateKey', isEqualTo: _dateKey(date));

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: settingsRef.get(),
      builder: (context, settingsSnap) {
        if (settingsSnap.hasError) {
          return Text('❌ Error settings: ${settingsSnap.error}');
        }
        if (!settingsSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final settings = settingsSnap.data!.data();
        if (settings == null) {
          return const Text('No hay settings/main configurado.');
        }

        final weeklyHours = (settings['weeklyHours'] as Map?) ?? {};
        final dayHours = weeklyHours['${_weekdayKey(date)}'];

        if (dayHours == null) {
          return const Center(child: Text('Cerrado este día.'));
        }

        final startStr = (dayHours['start'] ?? '09:00').toString();
        final endStr = (dayHours['end'] ?? '18:00').toString();
        const int stepMin = 30;


        final dayStart = _combine(date, startStr);
        final dayEnd = _combine(date, endStr);

        final allSlots =
            _generateSlots(start: dayStart, end: dayEnd, stepMin: stepMin);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: locksQuery.snapshots(),
          builder: (context, locksSnap) {
            if (locksSnap.hasError) {
              return Text('❌ Error locks: ${locksSnap.error}');
            }
            if (!locksSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            // ✅ slot_locks: { dateKey, hhmm, kind: 'appointment'|'block', ... }
            final taken = <String>{};
            for (final doc in locksSnap.data!.docs) {
              final d = doc.data();
              final hhmm = (d['hhmm'] ?? '').toString(); // "14:00"
              final kind = (d['kind'] ?? 'appointment').toString();
              if (hhmm.isNotEmpty && (kind == 'appointment' || kind == 'block')) {
                taken.add(hhmm);
              }
            }

            final nowBuffer = DateTime.now().add(const Duration(minutes: 30));

            final availableSlots = allSlots.where((s) {
              final hhmm = DateFormat('HH:mm').format(s);
              return !taken.contains(hhmm) && s.isAfter(nowBuffer);
            }).toList();

            if (availableSlots.isEmpty) {
              return const Center(child: Text('No hay horarios disponibles.'));
            }

return GridView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 4,
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
    childAspectRatio: 2.7,
  ),
  itemCount: availableSlots.length,
  itemBuilder: (context, index) {
    final slot = availableSlots[index]; // ✅ esta es tu lista real (DateTime)
    final t = TimeOfDay(hour: slot.hour, minute: slot.minute);

    final isSelected = selectedTime != null &&
        selectedTime!.hour == t.hour &&
        selectedTime!.minute == t.minute;

    // Si tu lista ya viene filtrada, no hace falta disabled.
    // Pero si aun querés tener ocupados deshabilitados:
    final isDisabled = false;

    return InkWell(
      onTap: isDisabled ? null : () => onPick(t),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isSelected
              ? Colors.black
              : isDisabled
                  ? Colors.grey.shade300
                  : Colors.grey.shade100,
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Text(
          DateFormat('HH:mm').format(slot),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: isSelected
                ? Colors.white
                : isDisabled
                    ? Colors.grey.shade600
                    : Colors.black,
          ),
        ),
      ),
    );
  },
);



          },
        );
      },
    );
  }
}
