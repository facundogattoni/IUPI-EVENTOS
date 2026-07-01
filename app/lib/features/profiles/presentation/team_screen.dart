import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile_repository.dart';
import '../domain/profile.dart';

/// Administración del equipo (solo administradores): cambiar nombre, rol y
/// estado de cada usuario. El alta de usuarios se hace desde Supabase Auth.
class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(allProfilesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Equipo')),
      body: profilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profiles) => ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Los usuarios se crean desde Supabase (Authentication). '
                'Acá podés ajustar su nombre y rol.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            for (final p in profiles) _ProfileTile(profile: p),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends ConsumerWidget {
  const _ProfileTile({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: profile.isActive
            ? null
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(profile.displayName.substring(0, 1).toUpperCase()),
      ),
      title: Text(profile.displayName),
      subtitle: Text(
          '${profile.role.label}${profile.isActive ? '' : ' · inactivo'}'),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () => _editProfile(context, ref, profile),
    );
  }

  Future<void> _editProfile(
      BuildContext context, WidgetRef ref, Profile profile) async {
    final name = TextEditingController(text: profile.fullName);
    UserRole role = profile.role;
    bool active = profile.isActive;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Editar ${profile.displayName}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nombre')),
              const SizedBox(height: 12),
              DropdownButtonFormField<UserRole>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: [
                  for (final r in UserRole.values)
                    DropdownMenuItem(value: r, child: Text(r.label)),
                ],
                onChanged: (v) => setModal(() => role = v ?? role),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Activo'),
                value: active,
                onChanged: (v) => setModal(() => active = v),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  await ref.read(profileRepositoryProvider).update(
                        Profile(
                          id: profile.id,
                          fullName: name.text.trim(),
                          role: role,
                          phone: profile.phone,
                          color: profile.color,
                          isActive: active,
                        ),
                      );
                  ref.invalidate(allProfilesProvider);
                  ref.invalidate(activeProfilesProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
