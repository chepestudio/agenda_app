import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'booking_success_page.dart';

class ClientForm extends StatefulWidget {
  final String businessId;
  final String businessName;
  final String businessPhone;

  final String serviceId;
  final String serviceName;
  final int durationMin;
  final DateTime startAt;

  const ClientForm({
    super.key,
    required this.businessId,
    required this.businessName,
    required this.businessPhone,
    required this.serviceId,
    required this.serviceName,
    required this.durationMin,
    required this.startAt,
  });

  @override
  State<ClientForm> createState() => _ClientFormState();
}

class _ClientFormState extends State<ClientForm> {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController(); // ✅ nuevo

  bool saving = false;
  String status = '';

  String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  bool _isValidEmail(String s) {
    final v = s.trim();
    if (v.isEmpty) return false;
    // validación MVP (suficiente por ahora)
    return v.contains('@') && v.contains('.');
  }

  Future<void> _createAppointment() async {
    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final email = emailCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      setState(() => status = 'Por favor completá nombre y WhatsApp.');
      return;
    }
    if (!_isValidEmail(email)) {
      setState(() => status = 'Por favor ingresá un correo válido.');
      return;
    }

    setState(() {
      saving = true;
      status = 'Guardando…';
    });

    try {
      final endAt = widget.startAt.add(Duration(minutes: widget.durationMin));
      final ref = FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId)
          .collection('appointments')
          .doc();

      await ref.set({
        'businessId': widget.businessId,
        'serviceId': widget.serviceId,
        'serviceName': widget.serviceName,

        'staffId': null,
        'staffName': null,

        'clientName': name,
        'clientPhone': phone,
        'clientEmail': email, // ✅ nuevo

        'startAt': widget.startAt,
        'endAt': endAt,

        'status': 'pending',
        'source': 'web',
        'startDateKey': _dateKey(widget.startAt),

        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

Navigator.of(context).pushReplacement(
  MaterialPageRoute(
    builder: (_) => BookingSuccessPage(
      businessName: widget.businessName,
      businessPhone: widget.businessPhone,
      serviceName: widget.serviceName,
      startAt: widget.startAt,
      durationMin: widget.durationMin, // ✅ obligatorio ahora
      clientName: name,
      // clientEmail: email, // ✅ opcional
    ),
  ),
);


    } catch (e) {
      if (!mounted) return;
      setState(() {
        saving = false;
        status = '❌ Error guardando: $e';
      });
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose(); // ✅ nuevo
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEE d MMM • HH:mm', 'es');
    final when = df.format(widget.startAt);

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar reserva')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${widget.serviceName}\n$when',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'WhatsApp'),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Correo'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saving ? null : _createAppointment,
                child: Text(saving ? 'Guardando…' : 'Reservar'),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(status),
            )
          ],
        ),
      ),
    );
  }
}
