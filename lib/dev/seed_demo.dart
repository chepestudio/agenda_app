import 'package:cloud_firestore/cloud_firestore.dart';

class SeedDemo {
  static Future<String> run() async {
    final db = FirebaseFirestore.instance;

    // ✅ slug (y será el documentId)
    const slug = 'barberia-demo';

    // 1) Crear negocio (ID = slug)
    final businessRef = db.collection('businesses').doc(slug);

    await businessRef.set({
      'name': 'Barbería Demo',
      'slug': slug,
      'phone': '+50680000000',
      'address': 'San José, CR',
      'timezone': 'America/Costa_Rica',
      'plan': 'basic',
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2) Settings
    await businessRef.collection('settings').doc('main').set({
      'bookingEnabled': true,
      'minNoticeHours': 2,
      'cancelNoticeHours': 4,
      'slotStepMin': 30, // slots de 30 min (MVP)
      'reminder24hEnabled': true,
      'reminder2hEnabled': true,
      'whatsappTemplates': {
        'confirmation':
            '✅ Tu cita quedó lista para {service} el {date} a las {time}.',
        'reminder24h':
            '⏰ Recordatorio: mañana tenés cita para {service} a las {time}. Confirmá aquí: {link}',
        'reminder2h': '🔥 Hoy es tu cita a las {time}. Te esperamos 🙌'
      },
      // Horario semanal (MVP simple)
      'weeklyHours': {
        // 1 = lunes ... 7 = domingo
        '1': {'start': '09:00', 'end': '18:00'},
        '2': {'start': '09:00', 'end': '18:00'},
        '3': {'start': '09:00', 'end': '18:00'},
        '4': {'start': '09:00', 'end': '18:00'},
        '5': {'start': '09:00', 'end': '18:00'},
        '6': {'start': '10:00', 'end': '16:00'},
        // en Firestore mejor NO guardar null explícito, solo omitir el día:
        // '7': null,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 3) Services (IDs legibles)
    final services = [
      {
        'id': 'corte',
        'name': 'Corte',
        'durationMin': 30,
        'price': 6000,
      },
      {
        'id': 'barba',
        'name': 'Barba',
        'durationMin': 30,
        'price': 4000,
      },
      {
        'id': 'corte-barba',
        'name': 'Corte + Barba',
        'durationMin': 60,
        'price': 9000,
      },
    ];

    for (final s in services) {
      final serviceId = s['id'] as String;

      await businessRef.collection('services').doc(serviceId).set({
        'name': s['name'],
        'durationMin': s['durationMin'],
        'price': s['price'],
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    return slug; // para abrir el booking
  }
}
