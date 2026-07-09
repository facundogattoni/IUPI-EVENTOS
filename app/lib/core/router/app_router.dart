import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/events/presentation/event_detail_screen.dart';
import '../../features/events/presentation/event_form_screen.dart';
import '../../features/shell/home_shell.dart';
import '../supabase/supabase_providers.dart';

/// Adapta un Stream a Listenable para que GoRouter reevalúe el redirect ante
/// cada cambio de sesión (login / logout / refresh de token).
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(supabaseClientProvider).auth;
  final refresh = _AuthRefresh(auth.onAuthStateChange);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = auth.currentSession != null;
      final loggingIn = state.matchedLocation == '/login';
      if (!loggedIn) return loggingIn ? null : '/login';
      if (loggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, __) => const HomeShell()),
      // 'new' debe ir antes que ':id' para no ser capturado por el parámetro.
      GoRoute(
        path: '/events/new',
        builder: (_, state) {
          final raw = state.uri.queryParameters['date'];
          final date = raw == null ? null : DateTime.tryParse(raw);
          return EventFormScreen(initialDate: date);
        },
      ),
      GoRoute(
        path: '/events/:id/edit',
        builder: (_, state) =>
            EventFormScreen(eventId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/events/:id',
        builder: (_, state) =>
            EventDetailScreen(eventId: state.pathParameters['id']!),
      ),
    ],
  );
});
