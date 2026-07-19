import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/username.dart';
import '../../auth/data/auth_repository.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';

/// Administración del equipo (solo administradores): crear usuarios, cambiar
/// nombre, rol y estado. Los trabajadores nunca ven finanzas (lo garantiza el RLS).
class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(allProfilesProvider);
    return profilesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (profiles) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: () => _showCreateUser(context, ref),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Agregar usuario'),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(
              'Los trabajadores y coordinadores entran con su email y contraseña. '
              'Un trabajador solo ve los cumpleaños asignados: nunca la facturación.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          for (final p in profiles) _ProfileTile(profile: p),
        ],
      ),
    );
  }

  Future<void> _showCreateUser(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CreateUserSheet(),
    );
  }
}

class _CreateUserSheet extends ConsumerStatefulWidget {
  const _CreateUserSheet();

  @override
  ConsumerState<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends ConsumerState<_CreateUserSheet> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.worker;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    final username = _email.text.trim();
    final pass = _password.text;
    if (name.isEmpty || username.isEmpty || username.contains(' ') ||
        pass.length < 6) {
      setState(() => _error =
          'Completá nombre, usuario (sin espacios) y una contraseña de 6+ caracteres.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await ref
          .read(authRepositoryProvider)
          .createAccount(email: emailFromLogin(username), password: pass);
      await ref
          .read(profileRepositoryProvider)
          .setRoleAndName(id: id, role: _role, fullName: name);
      ref.invalidate(allProfilesProvider);
      ref.invalidate(activeProfilesProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Usuario $name creado. Ya puede iniciar sesión.')),
        );
      }
    } on AuthException catch (e) {
      setState(() => _error = _friendly(e.message));
    } catch (e) {
      setState(() => _error = 'No se pudo crear: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _friendly(String raw) {
    if (raw.contains('already registered') ||
        raw.contains('already been registered')) {
      return 'Ya existe un usuario con ese email.';
    }
    if (raw.contains('Password')) return 'La contraseña es muy corta.';
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Nuevo usuario',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Nombre', prefixIcon: Icon(Icons.person_outline)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
                labelText: 'Usuario (ej: juan, sin espacios)',
                prefixIcon: Icon(Icons.person_outline)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            decoration: const InputDecoration(
                labelText: 'Contraseña temporal',
                prefixIcon: Icon(Icons.lock_outline)),
          ),
          const SizedBox(height: 16),
          const Text('Rol', style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 6),
          SegmentedButton<UserRole>(
            segments: const [
              ButtonSegment(
                  value: UserRole.worker,
                  label: Text('Trabajador'),
                  icon: Icon(Icons.badge_outlined)),
              ButtonSegment(
                  value: UserRole.coordinator,
                  label: Text('Coordinador'),
                  icon: Icon(Icons.stars_outlined)),
            ],
            selected: {_role},
            onSelectionChanged: (s) => setState(() => _role = s.first),
          ),
          const SizedBox(height: 6),
          Text(
            _role == UserRole.worker
                ? 'Ve solo los cumpleaños que le asignás. No ve finanzas.'
                : 'Puede crear y coordinar cumpleaños. No ve finanzas.',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _create,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Crear usuario'),
          ),
        ],
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
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: profile.isActive ? AppColors.brand : AppColors.surfaceAlt,
        child: Text(profile.displayName.substring(0, 1).toUpperCase(),
            style: const TextStyle(color: Colors.white)),
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
