import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../booking_shell.dart';
import 'service_picker.dart';

class BookingPage extends StatelessWidget {
  final String slug;
  const BookingPage({super.key, required this.slug});

  Future<QueryDocumentSnapshot<Map<String, dynamic>>> _getBusinessBySlug() async {
    final q = await FirebaseFirestore.instance
        .collection('businesses')
        .where('slug', isEqualTo: slug)
        .limit(1)
        .get();

    if (q.docs.isEmpty) {
      throw Exception('No existe negocio con slug="$slug"');
    }
    return q.docs.first;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QueryDocumentSnapshot<Map<String, dynamic>>>(
      future: _getBusinessBySlug(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('❌ ${snapshot.error}')),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final businessDoc = snapshot.data!;
        final businessId = businessDoc.id;
        final business = businessDoc.data();

        final name = (business['name'] ?? 'Negocio').toString();
        final phone = (business['phone'] ?? '').toString();

        return BookingShell(
          businessName: name,
          businessPhone: phone,
          step: 0,
          child: ServicePicker(
            businessId: businessId,
            businessSlug: slug,
            businessName: name,
            businessPhone: phone,
          ),
        );
      },
    );
  }
}
