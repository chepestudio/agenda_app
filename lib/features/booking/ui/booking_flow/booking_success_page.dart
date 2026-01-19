import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Para Flutter Web: descargar .ics
import 'dart:html' as html;

class BookingSuccessPage extends StatelessWidget {
  final String businessName;
  final String businessPhone;
  final String serviceName;
  final DateTime startAt;
  final int durationMin; // ✅ NUEVO
  final String clientName;
  final String? clientEmail; // ✅ OPCIONAL

  const BookingSuccessPage({
    super.key,
    required this.businessName,
    required this.businessPhone,
    required this.serviceName,
    required this.startAt,
    required this.durationMin, // ✅ NUEVO
    required this.clientName,
    this.clientEmail, // ✅ OPCIONAL
  });

  DateTime get _endAt => startAt.add(Duration(minutes: durationMin)); // ✅ EXACTO

  String _formatHuman(DateTime d) =>
      DateFormat('EEE d MMM • HH:mm', 'es').format(d);

  String _toIcsUtc(DateTime dt) {
    // iCalendar normalmente usa UTC con formato YYYYMMDDTHHMMSSZ
    final u = dt.toUtc();
    return DateFormat("yyyyMMdd'T'HHmmss'Z'").format(u);
  }

  String _escapeIcs(String s) {
    // Escapes básicos para iCalendar
    return s
        .replaceAll(r'\', r'\\')
        .replaceAll('\n', r'\n')
        .replaceAll(',', r'\,')
        .replaceAll(';', r'\;');
  }

  String _buildIcs() {
    final uid = '${DateTime.now().millisecondsSinceEpoch}@agenda_app';
    final dtStamp = _toIcsUtc(DateTime.now());
    final dtStart = _toIcsUtc(startAt);
    final dtEnd = _toIcsUtc(_endAt);

    final summary = _escapeIcs('$serviceName • $businessName');

    final emailLine = (clientEmail != null && clientEmail!.trim().isNotEmpty)
        ? 'Correo: ${clientEmail!.trim()}\n'
        : '';

    final description = _escapeIcs(
      'Reserva para $clientName.\n'
      '$emailLine'
      'Servicio: $serviceName\n'
      'Negocio: $businessName\n'
      'WhatsApp: $businessPhone\n',
    );

    final location = _escapeIcs(businessName);

    return [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//agenda_app//ES',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'BEGIN:VEVENT',
      'UID:$uid',
      'DTSTAMP:$dtStamp',
      'DTSTART:$dtStart',
      'DTEND:$dtEnd',
      'SUMMARY:$summary',
      'DESCRIPTION:$description',
      'LOCATION:$location',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');
  }

  void _downloadIcs() {
    final ics = _buildIcs();
    final bytes = utf8.encode(ics);
    final blob = html.Blob([bytes], 'text/calendar;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final filename =
        'reserva_${businessName.toLowerCase().replaceAll(" ", "_")}_${DateFormat('yyyyMMdd_HHmm').format(startAt)}.ics';

    final a = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  void _openWhatsapp() {
    // Link universal WhatsApp
    final phone = businessPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    final msg = Uri.encodeComponent(
      'Hola, soy $clientName. Confirmo mi cita de $serviceName el ${_formatHuman(startAt)} ✅',
    );
    final url = 'https://wa.me/$phone?text=$msg';
    html.window.open(url, '_blank');
  }

  @override
  Widget build(BuildContext context) {
    final when = _formatHuman(startAt);
    final endHuman = DateFormat('HH:mm', 'es').format(_endAt);

    return Scaffold(
      appBar: AppBar(title: const Text('Reserva confirmada')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 72),
                const SizedBox(height: 12),
                Text(
                  '¡Listo, $clientName!',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '$serviceName\n$when – $endHuman\n$businessName',
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                if (clientEmail != null && clientEmail!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    clientEmail!.trim(),
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),

                // ✅ Agregar a calendario
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _downloadIcs,
                    icon: const Icon(Icons.calendar_month),
                    label: const Text('Agregar al calendario'),
                  ),
                ),
                const SizedBox(height: 12),

                // WhatsApp (opcional)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openWhatsapp,
                    icon: const Icon(Icons.chat),
                    label: const Text('Enviar WhatsApp al negocio'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
