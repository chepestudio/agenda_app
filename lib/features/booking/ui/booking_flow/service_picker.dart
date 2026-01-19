import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'time_slot_picker.dart';

class ServicePicker extends StatelessWidget {
  final String businessId;
  final String businessSlug; // ✅ NUEVO
  final String businessName;
  final String businessPhone;

  const ServicePicker({
    super.key,
    required this.businessId,
    required this.businessSlug, // ✅ NUEVO
    required this.businessName,
    required this.businessPhone,
  });

  @override
  Widget build(BuildContext context) {
    final servicesQuery = FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('services')
        .where('isActive', isEqualTo: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: servicesQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StateBox(
            icon: Icons.error_outline,
            title: 'Error cargando servicios',
            subtitle: snapshot.error.toString(),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const _StateBox(
            icon: Icons.cut,
            title: 'No hay servicios disponibles',
            subtitle: 'Este negocio no tiene servicios activos todavía.',
          );
        }

        final sortedDocs = [...docs]..sort((a, b) {
            final an = (a.data()['name'] ?? '').toString();
            final bn = (b.data()['name'] ?? '').toString();
            return an.compareTo(bn);
          });

        return LayoutBuilder(
          builder: (context, c) {
            final isWide = c.maxWidth >= 720;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Elegí un servicio',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Seleccioná lo que querés reservar. Luego elegís fecha y hora.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black.withOpacity(0.55),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 18),

                      if (isWide)
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: sortedDocs.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 2.6,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemBuilder: (_, i) => _ServiceCard(
                            doc: sortedDocs[i],
                            businessId: businessId,
                            businessSlug: businessSlug, // ✅ NUEVO
                            businessName: businessName,
                            businessPhone: businessPhone,
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: sortedDocs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) => _ServiceCard(
                            doc: sortedDocs[i],
                            businessId: businessId,
                            businessSlug: businessSlug, // ✅ NUEVO
                            businessName: businessName,
                            businessPhone: businessPhone,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String businessId;
  final String businessSlug; // ✅ NUEVO
  final String businessName;
  final String businessPhone;

  const _ServiceCard({
    required this.doc,
    required this.businessId,
    required this.businessSlug, // ✅ NUEVO
    required this.businessName,
    required this.businessPhone,
  });

  String _moneyCRC(int amount) {
    // formato simple estilo ₡8,500
    final s = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idxFromEnd = s.length - i;
      buffer.write(s[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) buffer.write(',');
    }
    return '₡$buffer';
  }

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final serviceId = doc.id;

    final name = (d['name'] ?? 'Servicio').toString();

    final durationRaw = d['durationMin'] ?? 30;
    final durationMin = (durationRaw is num) ? durationRaw.toInt() : 30;

    final priceRaw = d['price'] ?? 0;
    final price = (priceRaw is num) ? priceRaw.toInt() : 0;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TimeSlotPicker(
              businessId: businessId,
              businessName: businessName,
              businessPhone: businessPhone,
              serviceId: serviceId,
              serviceName: name,
              durationMin: durationMin,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              blurRadius: 14,
              offset: const Offset(0, 8),
              color: Colors.black.withOpacity(0.05),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.black.withOpacity(0.06),
              ),
              child: const Icon(Icons.cut, size: 22),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      _Pill(
                        icon: Icons.schedule,
                        label: '$durationMin min',
                      ),
                      if (price > 0)
                        _Pill(
                          icon: Icons.payments_outlined,
                          label: _moneyCRC(price),
                        ),
                      if (price <= 0)
                        const _Pill(
                          icon: Icons.payments_outlined,
                          label: 'Precio a confirmar',
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.92),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Text(
                    'Seleccionar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Pill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.black.withOpacity(0.75)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.black.withOpacity(0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _StateBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _StateBox({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 60),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style:
                  TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.6)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
