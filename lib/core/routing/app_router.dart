import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../dev/dev_home.dart';
import '../../features/booking/ui/booking_flow/booking_page.dart';
import '../../features/booking/ui/booking_flow/booking_details_page.dart';


// Admin
import '../../features/admin/ui/admin_login_page.dart';
import '../../features/admin/ui/admin_appointments_page.dart';
import '../../features/admin/ui/admin_services_page.dart';
import '../../features/admin/ui/admin_shell.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // Home dev
    GoRoute(
      path: '/',
      builder: (context, state) => const DevHome(),
    ),

    // Booking público
    GoRoute(
      path: '/b/:slug',
      builder: (context, state) {
        final slug = state.pathParameters['slug']!;
        return BookingPage(slug: slug);
      },
    ),

    // ✅ Admin login (sin shell)
    GoRoute(
      path: '/admin/login',
      builder: (context, state) {
        final next = state.uri.queryParameters['next'];
        return AdminLoginPage(next: next);
      },
    ),

    // ✅ Admin con Shell (drawer + appbar)
    ShellRoute(
      builder: (context, state, child) {
        final slug = state.pathParameters['slug'] ?? '';
        return AdminShell(slug: slug, child: child);
      },
      routes: [
        // ✅ Calendario admin
        GoRoute(
          path: '/admin/:slug',
          redirect: (context, state) {
            final user = FirebaseAuth.instance.currentUser;
            if (user == null) {
              final next = Uri.encodeComponent(state.uri.toString());
              return '/admin/login?next=$next';
            }
            return null;
          },
          builder: (context, state) {
            final slug = state.pathParameters['slug']!;
            return AdminAppointmentsPage(slug: slug);
          },
        ),

     GoRoute(
  path: '/b/:slug/details',
  builder: (context, state) {
    final slug = state.pathParameters['slug']!;
    final extra = state.extra as Map<String, dynamic>?;

    // TODO: aquí luego usamos extra para pasar serviceId, startDateTime, etc.
    return BookingDetailsPage(
      businessId: slug,
      businessName: '',
      businessPhone: '',
      serviceId: '',
      serviceName: '',
      durationMin: 30,
      startDateTime: DateTime.now(),
    );
  },
),



        // ✅ Servicios admin
        GoRoute(
          path: '/admin/:slug/services',
          redirect: (context, state) {
            final user = FirebaseAuth.instance.currentUser;
            if (user == null) {
              final next = Uri.encodeComponent(state.uri.toString());
              return '/admin/login?next=$next';
            }
            return null;
          },
          builder: (context, state) {
            final slug = state.pathParameters['slug']!;
            return AdminServicesPage(slug: slug);
          },
        ),
      ],
    ),
  ],

  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text('Ruta no encontrada: ${state.uri}')),
  ),
);
