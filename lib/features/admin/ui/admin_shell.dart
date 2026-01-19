import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminShell extends StatelessWidget {
  final String slug;
  final Widget child;

  const AdminShell({
    super.key,
    required this.slug,
    required this.child,
  });

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    context.go('/admin/login?next=/admin/$slug');
  }

  @override
  Widget build(BuildContext context) {
    final title = 'Admin • $slug';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2E6EF),
        elevation: 0,
        centerTitle: true, // ✅ centra el título
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900, // ✅ negrita fuerte
          ),
        ),

        actions: [
          IconButton(
            tooltip: 'Salir',
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),

      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('Citas'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/admin/$slug');
                },
              ),
              ListTile(
                leading: const Icon(Icons.cut),
                title: const Text('Servicios'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/admin/$slug/services');
                },
              ),
            ],
          ),
        ),
      ),

      // ✅ IMPORTANTE: aquí va la página interna SIN Scaffold
      body: child,
    );
  }
}
