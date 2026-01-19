import 'package:flutter/material.dart';

class BookingShell extends StatelessWidget {
  final String businessName;
  final String? businessPhone;
  final Widget child;
  final int step; // 0=Servicio, 1=Fecha/Hora, 2=Datos

  const BookingShell({
    super.key,
    required this.businessName,
    this.businessPhone,
    required this.child,
    required this.step,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isDesktop = w >= 980;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.store, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                businessName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LeftInfo(
                        businessName: businessName,
                        businessPhone: businessPhone,
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: _RightCard(step: step, child: child)),
                    ],
                  )
                : Column(
                    children: [
                      _RightCard(step: step, child: child),
                      const SizedBox(height: 12),
                      _LeftInfo(
                        businessName: businessName,
                        businessPhone: businessPhone,
                        compact: true,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _RightCard extends StatelessWidget {
  final Widget child;
  final int step;

  const _RightCard({required this.child, required this.step});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias, // ✅ para que el splash respete bordes
      child: Material( // ✅ asegura Material ancestor SIEMPRE
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StepRow(step: step),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}


class _StepRow extends StatelessWidget {
  final int step;
  const _StepRow({required this.step});

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, int idx) {
      final active = idx == step;
      final done = idx < step;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? Colors.black
              : done
                  ? Colors.black.withOpacity(0.08)
                  : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? Colors.black : Colors.black.withOpacity(0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (done)
              const Icon(Icons.check, size: 16)
            else
              Text(
                '${idx + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : Colors.black54,
                ),
              ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('Servicio', 0),
        chip('Hora', 1),
        chip('Datos', 2),
      ],
    );
  }
}

class _LeftInfo extends StatelessWidget {
  final String businessName;
  final String? businessPhone;
  final bool compact;

  const _LeftInfo({
    required this.businessName,
    this.businessPhone,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? double.infinity : 320,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tu reserva',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(
                businessName,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.verified, size: 16, color: Colors.black.withOpacity(0.55)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Confirmación inmediata',
                      style: TextStyle(color: Colors.black.withOpacity(0.65)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if ((businessPhone ?? '').isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.chat, size: 16, color: Colors.black.withOpacity(0.55)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        businessPhone!,
                        style: TextStyle(color: Colors.black.withOpacity(0.65)),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 14),
              Text(
                'Elegí un servicio y un horario disponible.',
                style: TextStyle(color: Colors.black.withOpacity(0.70)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
