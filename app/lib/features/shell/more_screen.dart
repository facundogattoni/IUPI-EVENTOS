import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/data/auth_repository.dart';
import '../profiles/data/profile_repository.dart';

/// Sección "Más": perfil del usuario, accesos de administración y salir.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final profile = profileAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Más')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    child: Text(
                      (profile?.displayName ?? '?')
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile?.displayName ?? 'Usuario',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(profile?.role.label ?? '',
                          style: TextStyle(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (profile?.role.isAdmin ?? false)
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: const Text('Equipo'),
              subtitle: const Text('Administrar usuarios y roles'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/team'),
            ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Acerca de'),
            subtitle: const Text('IUPI Event Manager · v0.1'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'IUPI Event Manager',
              applicationVersion: '0.1.0',
              children: const [
                Text('Gestión del salón de eventos infantiles IUPI.'),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
            title: Text('Cerrar sesión',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () async {
              await ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
    );
  }
}
