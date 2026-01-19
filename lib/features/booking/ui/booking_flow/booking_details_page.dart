import 'dart:developer' as dev;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class BookingDetailsPage extends StatefulWidget {
  final String businessId;
  final String businessName;
  final String businessPhone;

  final String serviceId;
  final String serviceName;
  final int durationMin;

  final DateTime startDateTime;

  const BookingDetailsPage({
    super.key,
    required this.businessId,
    required this.businessName,
    required this.businessPhone,
    required this.serviceId,
    required this.serviceName,
    required this.durationMin,
    required this.startDateTime,
  });

  @override
  State<BookingDetailsPage> createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  String _startDateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _fmtGCalUtc(DateTime dtUtc) {
    String two(int v) => v.toString().padLeft(2, '0');
    final y = dtUtc.year.toString().padLeft(4, '0');
    final m = two(dtUtc.month);
    final d = two(dtUtc.day);
    final h = two(dtUtc.hour);
    final min = two(dtUtc.minute);
    final s = two(dtUtc.second);
    return '${y}${m}${d}T${h}${min}${s}Z';
  }

  String _googleCalendarUrl(DateTime selectedStart, String phone, String email) {
    final startUtc = selectedStart.toUtc();
    final endUtc =
        selectedStart.add(Duration(minutes: widget.durationMin)).toUtc();

    final dates = '${_fmtGCalUtc(startUtc)}/${_fmtGCalUtc(endUtc)}';
    final title = 'Reserva: ${widget.serviceName}';

    final details = '''
Reserva en ${widget.businessName}

Servicio: ${widget.serviceName} (${widget.durationMin} min)
Fecha/hora: ${selectedStart.day}/${selectedStart.month}/${selectedStart.year} ${selectedStart.hour.toString().padLeft(2, '0')}:${selectedStart.minute.toString().padLeft(2, '0')}
WhatsApp: ${phone.trim()}
Correo: ${email.trim()}
''';

    final uri = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': title,
      'dates': dates,
      'details': details,
    });

    return uri.toString();
  }

  Future<void> _openCalendar(DateTime start, String phone, String email) async {
    final url = _googleCalendarUrl(start, phone, email);
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'No se pudo abrir Google Calendar';
    }
  }

  Future<void> _confirm() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty || email.isEmpty) {
      setState(() => _error = 'Completa nombre, WhatsApp y correo.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final startAt = widget.startDateTime;
      final endAt =
          widget.startDateTime.add(Duration(minutes: widget.durationMin));

      final col = FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId)
          .collection('appointments');

      final data = {
        'businessId': widget.businessId,
        'serviceId': widget.serviceId,
        'serviceName': widget.serviceName,
        'staffId': '',
        'staffName': '',
        'clientName': name,
        'clientPhone': phone,
        'clientEmail': email,
        'startAt': Timestamp.fromDate(startAt),
        'endAt': Timestamp.fromDate(endAt),
        'status': 'pending',
        'source': 'web',
        'startDateKey': _startDateKey(startAt),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      dev.log('Creating appointment', name: 'booking', error: data);

      await col.add(data);

      if (!mounted) return;

      await _openCalendar(startAt, phone, email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reserva creada ✅')),
      );

      Navigator.pop(context);
    } catch (e, st) {
      dev.log('Booking error', name: 'booking', error: e, stackTrace: st);
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dt = widget.startDateTime;

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar reserva')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              widget.businessName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text('Servicio: ${widget.serviceName} (${widget.durationMin} min)'),
            const SizedBox(height: 6),
            Text(
              'Fecha/hora: ${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'WhatsApp',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Correo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _confirm,
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirmar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
