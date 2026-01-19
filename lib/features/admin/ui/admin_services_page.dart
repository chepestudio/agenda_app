import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminServicesPage extends StatefulWidget {
  final String slug;
  const AdminServicesPage({super.key, required this.slug});

  @override
  State<AdminServicesPage> createState() => _AdminServicesPageState();
}

class _AdminServicesPageState extends State<AdminServicesPage> {
  bool working = false;
  String status = '';

  Future<QueryDocumentSnapshot<Map<String, dynamic>>> _getBusinessBySlug() async {
    final q = await FirebaseFirestore.instance
        .collection('businesses')
        .where('slug', isEqualTo: widget.slug)
        .limit(1)
        .get();

    if (q.docs.isEmpty) {
      throw Exception('No existe negocio con slug="${widget.slug}"');
    }
    return q.docs.first;
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    context.go('/admin/login');
  }

  Future<void> _openServiceDialog({
    required String businessId,
    DocumentSnapshot<Map<String, dynamic>>? existing,
  }) async {
    final isEdit = existing != null;
    final data = existing?.data();

    final nameCtrl =
        TextEditingController(text: (data?['name'] ?? '').toString());

    final durationCtrl = TextEditingController(
      text: (data?['durationMin'] ?? 30).toString(),
    );

    final priceCtrl = TextEditingController(
      text: (data?['price'] ?? '').toString(),
    );

    bool isActive = (data?['isActive'] ?? true) == true;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isEdit ? 'Editar servicio' : 'Nuevo servicio'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: durationCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duración (min)',
                    hintText: 'Ej: 30',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Precio (opcional)',
                    hintText: 'Ej: 8500',
                  ),
                ),
                const SizedBox(height: 10),
                StatefulBuilder(
                  builder: (context, setLocal) {
                    return SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Activo'),
                      value: isActive,
                      onChanged: (v) => setLocal(() => isActive = v),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: working
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final duration = int.tryParse(durationCtrl.text.trim());
                      final priceTxt = priceCtrl.text.trim();
                      final price = priceTxt.isEmpty ? null : int.tryParse(priceTxt);

                      if (name.isEmpty || duration == null || duration <= 0) {
                        setState(() => status =
                            '❌ Nombre y duración válidos requeridos.');
                        Navigator.of(dialogContext).pop();
                        return;
                      }

                      setState(() {
                        working = true;
                        status = isEdit
                            ? 'Guardando cambios…'
                            : 'Creando servicio…';
                      });

                      try {
                        final ref = FirebaseFirestore.instance
                            .collection('businesses')
                            .doc(businessId)
                            .collection('services');

                        final payload = {
                          'name': name,
                          'durationMin': duration,
                          'price': price,
                          'isActive': isActive,
                          'updatedAt': FieldValue.serverTimestamp(),
                        };

                        if (isEdit) {
                          await ref.doc(existing!.id).set(
                                payload,
                                SetOptions(merge: true),
                              );
                        } else {
                          await ref.add({
                            ...payload,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                        }

                        setState(() {
                          working = false;
                          status = '✅ Listo.';
                        });

                        if (mounted) Navigator.of(dialogContext).pop();
                      } catch (e) {
                        setState(() {
                          working = false;
                          status = '❌ Error: $e';
                        });

                        if (mounted) Navigator.of(dialogContext).pop();
                      }
                    },
              child: Text(isEdit ? 'Guardar' : 'Crear'),
            ),
          ],
        );
      },
    );

    nameCtrl.dispose();
    durationCtrl.dispose();
    priceCtrl.dispose();
  }

  Future<void> _deleteService({
    required String businessId,
    required String serviceId,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar servicio'),
        content: const Text('¿Seguro? Esto lo quita del listado público.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() {
      working = true;
      status = 'Eliminando…';
    });

    try {
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .collection('services')
          .doc(serviceId)
          .delete();

      setState(() {
        working = false;
        status = '✅ Servicio eliminado.';
      });
    } catch (e) {
      setState(() {
        working = false;
        status = '❌ Error eliminando: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Esperar auth listo (web)
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (authSnap.data == null) {
          return Center(
            child: ElevatedButton(
              onPressed: () => context.go('/admin/login'),
              child: const Text('Ir a login'),
            ),
          );
        }

        return FutureBuilder<QueryDocumentSnapshot<Map<String, dynamic>>>(
          future: _getBusinessBySlug(),
          builder: (context, bizSnap) {
            if (bizSnap.hasError) {
              return Center(child: Text('❌ ${bizSnap.error}'));
            }

            if (!bizSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final businessId = bizSnap.data!.id;

            final servicesQuery = FirebaseFirestore.instance
                .collection('businesses')
                .doc(businessId)
                .collection('services')
                .orderBy('name');

            return Column(
              children: [
                if (status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(status),
                    ),
                  ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: servicesQuery.snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(child: Text('❌ ${snap.error}'));
                      }

                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snap.data!.docs;
                      if (docs.isEmpty) {
                        return const Center(
                          child: Text('No hay servicios todavía.'),
                        );
                      }

                      return ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final doc = docs[i];
                          final d = doc.data();

                          final name = (d['name'] ?? '').toString();
                          final durationMin = d['durationMin'];
                          final price = d['price'];
                          final isActive = (d['isActive'] ?? true) == true;

                          final durLabel = (durationMin is num)
                              ? '${durationMin.toInt()} min'
                              : '—';
                          final priceLabel =
                              (price is num) ? ' • ₡${price.toInt()}' : '';

                          return ListTile(
                            title: Text(name),
                            subtitle: Text('$durLabel$priceLabel'),
                            leading: Icon(
                              isActive ? Icons.check_circle : Icons.cancel,
                            ),
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: working
                                      ? null
                                      : () => _openServiceDialog(
                                            businessId: businessId,
                                            existing: doc,
                                          ),
                                  child: const Text('Editar'),
                                ),
                                TextButton(
                                  onPressed: working
                                      ? null
                                      : () => _deleteService(
                                            businessId: businessId,
                                            serviceId: doc.id,
                                          ),
                                  child: const Text('Eliminar'),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: working
                              ? null
                              : () => _openServiceDialog(businessId: businessId),
                          icon: const Icon(Icons.add),
                          label: const Text('Nuevo servicio'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: 'Salir',
                        onPressed: _logout,
                        icon: const Icon(Icons.logout),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
