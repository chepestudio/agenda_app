import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import 'admin_appointment_detail_page.dart';

class AdminAppointmentsPage extends StatefulWidget {
  final String slug;
  const AdminAppointmentsPage({super.key, required this.slug});

  @override
  State<AdminAppointmentsPage> createState() => _AdminAppointmentsPageState();
}

class _AdminAppointmentsPageState extends State<AdminAppointmentsPage> {
  static const int stepMin = 15; // ✅ intervalo de slots del calendario

  DateTime selectedDate = DateTime.now();
  String status = '';
  bool working = false;


  // ---------------- Helpers base ----------------
  String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _hhmm(DateTime d) => DateFormat('HH:mm').format(d);

  String _hhmmFloor(DateTime d, int stepMin) {
    final totalMin = d.hour * 60 + d.minute;
    final floored = (totalMin ~/ stepMin) * stepMin;
    final hh = (floored ~/ 60).toString().padLeft(2, '0');
    final mm = (floored % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }


  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _combine(DateTime day, String hhmm) {
    final parts = hhmm.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    return DateTime(day.year, day.month, day.day, h, m);
  }

  String _statusLabel(String st) {
    switch (st) {
      case 'pending':
        return 'PENDIENTE';
      case 'confirmed':
        return 'CONFIRMADA';
      case 'cancelled':
        return 'CANCELADA';
      default:
        return st.toUpperCase();
    }
  }

  // ---------------- Semana (chips Lun–Dom) ----------------
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

  Widget _weekChips() {
    final days = _weekDays(selectedDate);

    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, i) {
          final d = days[i];
          final selected = _isSameDay(d, selectedDate);

          return ChoiceChip(
            label: Text(_chipLabel(d)),
            selected: selected,
            onSelected: (_) => setState(() => selectedDate = d),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: days.length,
      ),
    );
  }

  // ---------------- Firestore: business por slug ----------------
  Future<QueryDocumentSnapshot<Map<String, dynamic>>> _getBusinessBySlug() async {
    final q = await FirebaseFirestore.instance
        .collection('businesses')
        .where('slug', isEqualTo: widget.slug)
        .limit(1)
        .get();

    if (q.docs.isEmpty) {
      throw Exception('No existe negocio con slug="${widget.slug}"');
    }
    return q.docs.first;
  }

  // ---------------- UI actions ----------------
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate:
          DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30)),
      lastDate: DateTime(now.year, now.month + 6, now.day),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    context.go('/admin/login');
  }

  // ---------------- Confirmar / Cancelar ----------------
  Future<void> _setAppointmentStatus({
    required String businessId,
    required String appointmentId,
    required String statusValue, // confirmed | cancelled
  }) async {
    if (working) return;

    setState(() {
      working = true;
      status = statusValue == 'confirmed' ? 'Confirmando…' : 'Cancelando…';
    });

    final db = FirebaseFirestore.instance;

    try {
      final apptRef = db
          .collection('businesses')
          .doc(businessId)
          .collection('appointments')
          .doc(appointmentId);

      await apptRef.update({
        'status': statusValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Si se cancela: liberar locks ligados a appointmentId
      if (statusValue == 'cancelled') {
        final locksQ = await db
            .collection('businesses')
            .doc(businessId)
            .collection('slot_locks')
            .where('appointmentId', isEqualTo: appointmentId)
            .get();

        final batch = db.batch();
        for (final doc in locksQ.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      setState(() {
        working = false;
        status = statusValue == 'confirmed'
            ? '✅ Cita confirmada.'
            : '✅ Cita cancelada y locks liberados.';
      });
    } catch (e) {
      setState(() {
        working = false;
        status = '❌ Error: $e';
      });
    }
  }

  // ---------------- Settings: horario + step ----------------
  Future<Map<String, dynamic>> _getMainSettings(String businessId) async {
    final ref = FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('settings')
        .doc('main');
    final snap = await ref.get();
    return snap.data() ?? {};
  }

  int _weekdayKey(DateTime d) => d.weekday; // 1..7

  // Devuelve {dayStart, dayEnd, stepMin} o null si cerrado
  Future<({DateTime dayStart, DateTime dayEnd, int stepMin})?> _dayWindow(
    String businessId,
    DateTime day,
  ) async {
    final settings = await _getMainSettings(businessId);
    final weeklyHours = (settings['weeklyHours'] as Map?) ?? {};
    final dayHours = weeklyHours['${_weekdayKey(day)}'];

    if (dayHours == null) return null;

    final startStr = (dayHours['start'] ?? '09:00').toString();
    final endStr = (dayHours['end'] ?? '18:00').toString();
    final step = settings['slotStepMin'] ?? 30;
    final stepMin = (step is num) ? step.toInt() : 30;

    final dayStart = _combine(day, startStr);
    final dayEnd = _combine(day, endStr);

    return (dayStart: dayStart, dayEnd: dayEnd, stepMin: stepMin);
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

  // ---------------- Bloqueos admin (slot_locks kind=block) ----------------
  Future<void> _createBlock({
    required String businessId,
    required DateTime day,
    required String startHHMM,
    required int durationMin,
    required int stepMin,
    String reason = '',
  }) async {
    if (working) return;

    setState(() {
      working = true;
      status = 'Bloqueando…';
    });

    try {
      final startAt = _combine(day, startHHMM);
      final endAt = startAt.add(Duration(minutes: durationMin));

      final locks = <DateTime>[];
      var cur = startAt;
      while (cur.isBefore(endAt)) {
        locks.add(cur);
        cur = cur.add(Duration(minutes: stepMin));
      }

      final uid = FirebaseAuth.instance.currentUser?.uid;

      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      for (final t in locks) {
        final lockRef = db
            .collection('businesses')
            .doc(businessId)
            .collection('slot_locks')
            .doc();

        batch.set(lockRef, {
          'kind': 'block',
          'dateKey': _dateKey(day),
          'hhmm': _hhmm(t),
          'startAt': Timestamp.fromDate(t),
          'endAt': Timestamp.fromDate(t.add(Duration(minutes: stepMin))),
          'reason': reason,
          'createdBy': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      setState(() {
        working = false;
        status = '✅ Bloqueo creado (${locks.length} slots).';
      });
    } catch (e) {
      setState(() {
        working = false;
        status = '❌ Error bloqueando: $e';
      });
    }
  }

  // Borra locks tipo block para (dateKey + hhmm) y (cantidadSlots)
  Future<void> _deleteBlockRange({
    required String businessId,
    required DateTime day,
    required String startHHMM,
    required int durationMin,
    required int stepMin,
  }) async {
    if (working) return;

    setState(() {
      working = true;
      status = 'Desbloqueando…';
    });

    try {
      final startAt = _combine(day, startHHMM);
      final endAt = startAt.add(Duration(minutes: durationMin));

      final targets = <String>{};
      var cur = startAt;
      while (cur.isBefore(endAt)) {
        targets.add(_hhmm(cur));
        cur = cur.add(Duration(minutes: stepMin));
      }

      final db = FirebaseFirestore.instance;
      final q = await db
          .collection('businesses')
          .doc(businessId)
          .collection('slot_locks')
          .where('dateKey', isEqualTo: _dateKey(day))
          .where('kind', isEqualTo: 'block')
          .get();

      final batch = db.batch();
      int deleted = 0;

      for (final doc in q.docs) {
        final d = doc.data();
        final hhmm = (d['hhmm'] ?? '').toString();
        if (targets.contains(hhmm)) {
          batch.delete(doc.reference);
          deleted++;
        }
      }

      await batch.commit();

      setState(() {
        working = false;
        status = '✅ Bloqueo eliminado ($deleted slots).';
      });
    } catch (e) {
      setState(() {
        working = false;
        status = '❌ Error desbloqueando: $e';
      });
    }
  }

  void _openBlockDialog({
    required String businessId,
    required DateTime day,
    required String defaultHHMM,
    required int stepMin,
  }) {
    final startCtrl = TextEditingController(text: defaultHHMM);
    final reasonCtrl = TextEditingController();
    int durationMin = 60;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Bloquear horario'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Día: ${DateFormat('EEE d MMM', 'es').format(day)}'),
              const SizedBox(height: 12),
              TextField(
                controller: startCtrl,
                decoration: const InputDecoration(
                  labelText: 'Hora inicio (HH:mm)',
                  hintText: '09:00',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: durationMin,
                items: const [
                  DropdownMenuItem(value: 30, child: Text('30 min')),
                  DropdownMenuItem(value: 60, child: Text('60 min')),
                  DropdownMenuItem(value: 90, child: Text('90 min')),
                  DropdownMenuItem(value: 120, child: Text('120 min')),
                ],
                onChanged: (v) => durationMin = v ?? 60,
                decoration: const InputDecoration(labelText: 'Duración'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Razón (opcional)',
                  hintText: 'Ej: almuerzo, reunión…',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: working ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: working
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await _createBlock(
                        businessId: businessId,
                        day: day,
                        startHHMM: startCtrl.text.trim(),
                        durationMin: durationMin,
                        stepMin: stepMin,
                        reason: reasonCtrl.text.trim(),
                      );
                    },
              child: const Text('Bloquear'),
            ),
          ],
        );
      },
    );
  }

  void _openUnblockDialog({
    required String businessId,
    required DateTime day,
    required String startHHMM,
    required int stepMin,
  }) {
    int durationMin = 60;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Desbloquear horario'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Inicio: $startHHMM'),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: durationMin,
                items: const [
                  DropdownMenuItem(value: 30, child: Text('30 min')),
                  DropdownMenuItem(value: 60, child: Text('60 min')),
                  DropdownMenuItem(value: 90, child: Text('90 min')),
                  DropdownMenuItem(value: 120, child: Text('120 min')),
                ],
                onChanged: (v) => durationMin = v ?? 60,
                decoration: const InputDecoration(labelText: 'Duración a liberar'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: working ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: working
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await _deleteBlockRange(
                        businessId: businessId,
                        day: day,
                        startHHMM: startHHMM,
                        durationMin: durationMin,
                        stepMin: stepMin,
                      );
                    },
              child: const Text('Desbloquear'),
            ),
          ],
        );
      },
    );
  }

  // ---------------- UI: fila tipo “Calendly” ----------------
  Widget _timeRow({
    required String hhmm,
    required bool isNowishMarker,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Row(
              children: [
                Text(
                  hhmm,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.black.withOpacity(0.75),
                  ),
                ),
                const SizedBox(width: 6),
                if (isNowishMarker)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.redAccent,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _pill(String text, {Color? bg, Color? fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg ?? Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg ?? Colors.black.withOpacity(0.75),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dfTitle = DateFormat('EEEE d MMM', 'es');
    final dateKey = _dateKey(selectedDate);

    // ✅ 1) Esperar a que Auth esté listo (web)
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnap.data;
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Admin')),
            body: Center(
              child: ElevatedButton(
                onPressed: () => context.go('/admin/login'),
                child: const Text('Ir a login'),
              ),
            ),
          );
        }

        // ✅ 2) Auth listo → business por slug
        return FutureBuilder<QueryDocumentSnapshot<Map<String, dynamic>>>(
          future: _getBusinessBySlug(),
          builder: (context, bizSnap) {
            if (bizSnap.hasError) {
              return Scaffold(
                appBar: AppBar(title: const Text('Admin')),
                body: Center(child: Text('❌ ${bizSnap.error}')),
              );
            }
            if (!bizSnap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final businessDoc = bizSnap.data!;
            final businessId = businessDoc.id;

            // 3) Cargar ventana del día (horario + step)
            return FutureBuilder<({DateTime dayStart, DateTime dayEnd, int stepMin})?>(
              future: _dayWindow(businessId, selectedDate),
              builder: (context, winSnap) {
                if (!winSnap.hasData) {
                  return Scaffold(
                    appBar: AppBar(
                      title: Text('Admin • ${widget.slug}'),
                      actions: [
                        IconButton(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.date_range),
                          tooltip: 'Cambiar fecha',
                        ),
                        IconButton(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout),
                          tooltip: 'Salir',
                        ),
                      ],
                    ),
                    body: Column(
                      children: [
                        const SizedBox(height: 10),
                        _weekChips(),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Cerrado este día.',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final win = winSnap.data!;
                final allSlots = _generateSlots(
                  start: win.dayStart,
                  end: win.dayEnd,
                  stepMin: win.stepMin,
                );

                final appointmentsQuery = FirebaseFirestore.instance
                    .collection('businesses')
                    .doc(businessId)
                    .collection('appointments')
                    .where('startDateKey', isEqualTo: dateKey)
                    .orderBy('startAt');

                final locksQuery = FirebaseFirestore.instance
                    .collection('businesses')
                    .doc(businessId)
                    .collection('slot_locks')
                    .where('dateKey', isEqualTo: dateKey);

                return Scaffold(
                  appBar: AppBar(
                    title: Text('Admin • ${widget.slug}'),
                    actions: [
                      IconButton(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.date_range),
                        tooltip: 'Cambiar fecha',
                      ),
                      IconButton(
                        onPressed: working
                            ? null
                            : () => _openBlockDialog(
                                  businessId: businessId,
                                  day: selectedDate,
                                  defaultHHMM: _hhmm(DateTime.now()),
                                  stepMin: win.stepMin,
                                ),
                        icon: const Icon(Icons.block),
                        tooltip: 'Bloquear horario',
                      ),
                      IconButton(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout),
                        tooltip: 'Salir',
                      ),
                    ],
                  ),
                  body: Column(
                    children: [
                      const SizedBox(height: 10),
                      _weekChips(),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Agenda: ${dfTitle.format(selectedDate)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            _pill('${win.stepMin} min'),
                            const SizedBox(width: 8),
                            if (working)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ✅ Timeline: combinamos appointments + locks en 2 streams
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: appointmentsQuery.snapshots(),
                          builder: (context, apptSnap) {
                            if (apptSnap.hasError) {
                              return Center(child: Text('❌ ${apptSnap.error}'));
                            }
                            if (!apptSnap.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            final appts = apptSnap.data!.docs;

                            // Indexar citas por HH:mm (solo por startAt)
                            final apptByHHMM = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
                            for (final doc in appts) {
                              final d = doc.data();
                              final ts = d['startAt'];
                              if (ts is Timestamp) {
                                final dt = ts.toDate();
                                apptByHHMM[_hhmm(dt)] = doc;
                              }
                            }

                            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: locksQuery.snapshots(),
                              builder: (context, locksSnap) {
                                if (locksSnap.hasError) {
                                  return Center(child: Text('❌ ${locksSnap.error}'));
                                }
                                if (!locksSnap.hasData) {
                                  return const Center(child: CircularProgressIndicator());
                                }

                                // Indexar locks por HH:mm
                                // Nota: puede haber locks appointment o block.
                                final lockByHHMM = <String, Map<String, dynamic>>{};
                                final lockDocIdByHHMM = <String, String>{};

                                for (final doc in locksSnap.data!.docs) {
                                  final d = doc.data();
                                  final hhmm = (d['hhmm'] ?? '').toString();
                                  if (hhmm.isEmpty) continue;
                                  lockByHHMM[hhmm] = d;
                                  lockDocIdByHHMM[hhmm] = doc.id;
                                }

                                final now = DateTime.now();

                                return ListView.builder(
                                  itemCount: allSlots.length,
                                  itemBuilder: (context, i) {
                                    final slot = allSlots[i];
                                    final hhmm = _hhmmFloor(slot, stepMin);

                                    final apptDoc = apptByHHMM[hhmm];
                                    final lock = lockByHHMM[hhmm];

                                    final isNowishMarker = _isSameDay(slot, now) &&
                                        (slot.isAfter(now.subtract(const Duration(minutes: 1))) &&
                                            slot.isBefore(now.add(const Duration(minutes: 20))));

                                    // 1) Hay cita
                                    if (apptDoc != null) {
                                      final d = apptDoc.data();
                                      final clientName = (d['clientName'] ?? '').toString();
                                      final clientPhone = (d['clientPhone'] ?? '').toString();
                                      final serviceName = (d['serviceName'] ?? '').toString();
                                      final st = (d['status'] ?? 'pending').toString();
                                      final cancelled = st == 'cancelled';

                                      return _timeRow(
                                        hhmm: hhmm,
                                        isNowishMarker: isNowishMarker,
                                        child: InkWell(
                                          onTap: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => AdminAppointmentDetailPage(
                                                  businessId: businessId,
                                                  appointmentId: apptDoc.id,
                                                ),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: cancelled
                                                  ? Colors.black.withOpacity(0.04)
                                                  : Colors.black.withOpacity(0.03),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: Colors.black.withOpacity(0.06),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        serviceName,
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w800,
                                                        ),
                                                      ),
                                                    ),
                                                    _pill(
                                                      _statusLabel(st),
                                                      bg: cancelled
                                                          ? Colors.black.withOpacity(0.08)
                                                          : (st == 'confirmed'
                                                              ? Colors.green.withOpacity(0.15)
                                                              : Colors.orange.withOpacity(0.15)),
                                                      fg: st == 'confirmed'
                                                          ? Colors.green.shade800
                                                          : (st == 'pending'
                                                              ? Colors.orange.shade900
                                                              : Colors.black.withOpacity(0.7)),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  '$clientName • $clientPhone',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.black.withOpacity(0.70),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                if (!cancelled)
                                                  Wrap(
                                                    spacing: 8,
                                                    children: [
                                                      if (st == 'pending')
                                                        OutlinedButton(
                                                          onPressed: working
                                                              ? null
                                                              : () => _setAppointmentStatus(
                                                                    businessId: businessId,
                                                                    appointmentId: apptDoc.id,
                                                                    statusValue: 'confirmed',
                                                                  ),
                                                          child: const Text('Confirmar'),
                                                        ),
                                                      TextButton(
                                                        onPressed: working
                                                            ? null
                                                            : () => _setAppointmentStatus(
                                                                  businessId: businessId,
                                                                  appointmentId: apptDoc.id,
                                                                  statusValue: 'cancelled',
                                                                ),
                                                        child: const Text('Cancelar'),
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    // 2) No hay cita, pero hay lock
                                    if (lock != null) {
                                      final kind = (lock['kind'] ?? '').toString();
                                      final reason = (lock['reason'] ?? '').toString();

                                      // Mostrar locks block como bloqueado.
                                      // Si es lock de appointment sin cita (raro), igual lo marcamos ocupado.
                                      final isBlock = kind == 'block';

                                      return _timeRow(
                                        hhmm: hhmm,
                                        isNowishMarker: isNowishMarker,
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isBlock
                                                ? Colors.grey.withOpacity(0.18)
                                                : Colors.black.withOpacity(0.06),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: Colors.black.withOpacity(0.08),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      isBlock ? 'Bloqueado' : 'Ocupado',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w900,
                                                      ),
                                                    ),
                                                    if (reason.trim().isNotEmpty) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        reason,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.black.withOpacity(0.70),
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              if (isBlock)
                                                TextButton(
                                                  onPressed: working
                                                      ? null
                                                      : () => _openUnblockDialog(
                                                            businessId: businessId,
                                                            day: selectedDate,
                                                            startHHMM: hhmm,
                                                            stepMin: win.stepMin,
                                                          ),
                                                  child: const Text('Desbloquear'),
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }

                                    // 3) Slot libre → tap para bloquear rápido
                                    return _timeRow(
                                      hhmm: hhmm,
                                      isNowishMarker: isNowishMarker,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(14),
                                        onTap: working
                                            ? null
                                            : () => _openBlockDialog(
                                                  businessId: businessId,
                                                  day: selectedDate,
                                                  defaultHHMM: hhmm,
                                                  stepMin: win.stepMin,
                                                ),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.transparent,
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: Colors.black.withOpacity(0.06),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Libre',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.black.withOpacity(0.55),
                                                  ),
                                                ),
                                              ),
                                              _pill('Bloquear', bg: Colors.black.withOpacity(0.06)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),

                      if (status.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(status),
                          ),
                        ),
                    ],
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
