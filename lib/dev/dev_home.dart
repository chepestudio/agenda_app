import 'package:flutter/material.dart';
import 'seed_demo.dart';

class DevHome extends StatefulWidget {
  const DevHome({super.key});

  @override
  State<DevHome> createState() => _DevHomeState();
}

class _DevHomeState extends State<DevHome> {
  String status = 'Listo.';
  String? slug;

  Future<void> _seed() async {
    setState(() => status = 'Creando demo data…');

    try {
      final s = await SeedDemo.run();

      setState(() {
        slug = s;
        status = '✅ Demo creada. Slug: $s';
      });
    } catch (e) {
      setState(() => status = '❌ Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final urlHint = slug == null
        ? ''
        : 'Abrí: /#/b/$slug (si estás en Flutter web con hash)';

    return Scaffold(
      appBar: AppBar(title: const Text('Dev Home')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _seed,
              child: const Text('Seed demo data (business + services)'),
            ),
            const SizedBox(height: 12),
            Text(status),
            if (slug != null) ...[
              const SizedBox(height: 8),
              Text(urlHint),
            ],
          ],
        ),
      ),
    );
  }
}
