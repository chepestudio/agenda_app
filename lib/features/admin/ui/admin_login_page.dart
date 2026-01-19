import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminLoginPage extends StatefulWidget {
  final String? next; // ✅ opcional: ruta destino
  const AdminLoginPage({super.key, this.next});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;
  String status = '';

  Future<void> _login() async {
    final email = emailCtrl.text.trim();
    final pass = passCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      setState(() => status = 'Completá email y contraseña.');
      return;
    }

    setState(() {
      loading = true;
      status = '';
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );

      if (!mounted) return;

      // ✅ 1) prioridad: next (si venía de otra ruta protegida)
      final next = widget.next;
      if (next != null && next.isNotEmpty) {
        context.go(next);
        return;
      }

      // ✅ 2) si no hay next, buscamos slug en query params:
      // Ej: /admin/login?slug=barberia-demo
      final slug = GoRouterState.of(context).uri.queryParameters['slug'];
      if (slug != null && slug.isNotEmpty) {
        context.go('/admin/$slug');
        return;
      }

      // ✅ 3) fallback
      context.go('/');

    } catch (e) {
      setState(() {
        loading = false;
        status = '❌ $e';
      });
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passCtrl,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : _login,
                child: Text(loading ? 'Entrando…' : 'Entrar'),
              ),
            ),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: Text(status)),
          ],
        ),
      ),
    );
  }
}
