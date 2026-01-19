import 'package:flutter/material.dart';

class BookingShell extends StatelessWidget {
  final String businessName;
  final String businessPhone;
  final int step; // 0..4
  final Widget child;

  const BookingShell({
    super.key,
    required this.businessName,
    required this.businessPhone,
    required this.step,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _Header(
                    businessName: businessName,
                    businessPhone: businessPhone,
                  ),
                  const SizedBox(height: 14),
                  _Stepper(step: step),
                  const SizedBox(height: 14),

                  // ✅ IMPORTANTE: el contenido debe poder scrollear
Expanded(
  child: Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          blurRadius: 16,
          offset: const Offset(0, 8),
          color: Colors.black.withOpacity(0.06),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    ),
  ),
),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String businessName;
  final String businessPhone;

  const _Header({
    required this.businessName,
    required this.businessPhone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 6),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black.withOpacity(0.06),
            ),
            child: const Icon(Icons.storefront),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  businessName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  businessPhone.isEmpty ? '—' : businessPhone,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Reserva online',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final int step;
  const _Stepper({required this.step});

  @override
  Widget build(BuildContext context) {
    final items = const [
      ('Servicio', Icons.cut),
      ('Fecha', Icons.calendar_today),
      ('Hora', Icons.schedule),
      ('Datos', Icons.person),
      ('Confirmación', Icons.check_circle),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final active = i <= step;
          final icon = items[i].$2;
          final label = items[i].$1;

          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active
                        ? Colors.black.withOpacity(0.90)
                        : Colors.black.withOpacity(0.08),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: active ? Colors.white : Colors.black.withOpacity(0.55),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: active
                          ? Colors.black.withOpacity(0.92)
                          : Colors.black.withOpacity(0.40),
                    ),
                  ),
                ),
                if (i != items.length - 1)
                  Container(
                    width: 22,
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: Colors.black.withOpacity(active ? 0.25 : 0.08),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
