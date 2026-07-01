import 'package:flutter/material.dart';

/// Roles del sistema. El acceso real lo garantiza RLS en la base; acá solo
/// adaptamos la interfaz a lo que cada rol necesita ver.
enum UserRole {
  admin,
  coordinator,
  worker;

  static UserRole fromDb(String? value) {
    switch (value) {
      case 'admin':
        return UserRole.admin;
      case 'coordinator':
        return UserRole.coordinator;
      default:
        return UserRole.worker;
    }
  }

  String get db => name;

  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Administrador';
      case UserRole.coordinator:
        return 'Coordinador';
      case UserRole.worker:
        return 'Trabajador';
    }
  }

  bool get isAdmin => this == UserRole.admin;
  bool get canManageEvents => this == UserRole.admin || this == UserRole.coordinator;
}

@immutable
class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.role,
    this.phone,
    this.color,
    this.isActive = true,
  });

  final String id;
  final String fullName;
  final UserRole role;
  final String? phone;
  final String? color;
  final bool isActive;

  String get displayName => fullName.trim().isEmpty ? 'Sin nombre' : fullName;

  /// Color asignado para pintar sus eventos en el calendario (o uno derivado).
  Color colorOrDefault(BuildContext context) {
    if (color != null && color!.isNotEmpty) {
      final hex = color!.replaceFirst('#', '');
      final value = int.tryParse('FF$hex', radix: 16);
      if (value != null) return Color(value);
    }
    // Color estable derivado del id.
    const palette = Colors.primaries;
    return palette[id.hashCode.abs() % palette.length];
  }

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      fullName: (map['full_name'] as String?) ?? '',
      role: UserRole.fromDb(map['role'] as String?),
      phone: map['phone'] as String?,
      color: map['color'] as String?,
      isActive: (map['is_active'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toUpdateMap() => {
        'full_name': fullName,
        'role': role.db,
        'phone': phone,
        'color': color,
        'is_active': isActive,
      };
}
