import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminAppointmentDetailPage extends StatelessWidget {
  final String businessId;
  final String appointmentId;

  const AdminAppointmentDetailPage({
    super.key,
    required this.businessId,
    required this.appointmentId,
  });

  String _waLink({
    required String phone,
    required String message,
  }) {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final encoded = Uri.encodeComponent(message);
    return "https://wa.me/$clean?text=$encoded";
  }

  Future<void> _setAppointmentStatus({
    required String statusValue, // confirmed | cancelled
  }) async {
    final db = FirebaseFirestore.instance;
    final apptRef = db
        .collection('businesses')
        .doc(businessId)
        .collection('appointments')
        .doc(appointmentId);

    await apptRef.update({
      'status': statusValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Si se cancela: liberar locks
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
  }

  @override
  Widget build(BuildContext context) {
    final apptRef = FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('appointments')
        .doc(appointmentId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: apptRef.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalle cita')),
            body: Center(child: Text('❌ ${snap.error}')),
          );
        }
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snap.data!.data();
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalle cita')),
            body: const Center(child: Text('No existe la cita.')),
          );
        }

        final clientName = (data['clientName'] ?? '').toString();
        final clientPhone = (data['clientPhone'] ?? '').toString();
        final serviceName = (data['serviceName'] ?? '').toString();
        final st = (data['status'] ?? 'pending').toString();

        DateTime? startAt;
        final ts = data['startAt'];
        if (ts is Timestamp) startAt = ts.toDate();

        final when = startAt == null
            ? '—'
            : DateFormat('EEEE d MMM yyyy • HH:mm', 'es').format(startAt);

        final isCancelled = st == 'cancelled';
        final isPending = st == 'pending';

        final waMessage = startAt == null
            ? 'Hola $clientName 👋'
            : 'Hola $clientName 👋 Te confirmo tu cita de *$serviceName* para *$when*.';

        return Scaffold(
          appBar: AppBar(title: const Text('Detalle cita')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  serviceName.isEmpty ? 'Servicio' : serviceName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Estado: ${st.toUpperCase()}'),
                const SizedBox(height: 8),
                Text('Fecha: $when'),
                const Divider(height: 32),

                Text('Cliente: $clientName'),
                const SizedBox(height: 4),
                Text('WhatsApp: $clientPhone'),

                const Spacer(),

                if (!isCancelled)
                  Row(
                    children: [
                      if (isPending)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              await _setAppointmentStatus(statusValue: 'confirmed');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('✅ Cita confirmada')),
                                );
                              }
                            },
                            child: const Text('Confirmar'),
                          ),
                        ),
                      if (isPending) const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await _setAppointmentStatus(statusValue: 'cancelled');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('✅ Cita cancelada')),
                              );
                              Navigator.pop(context);
                            }
                          },
                          child: const Text('Cancelar'),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: clientPhone.trim().isEmpty
                        ? null
                        : () async {
                            final url = Uri.parse(
                              _waLink(phone: clientPhone, message: waMessage),
                            );
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          },
                    icon: const Icon(Icons.chat),
                    label: const Text('WhatsApp'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
