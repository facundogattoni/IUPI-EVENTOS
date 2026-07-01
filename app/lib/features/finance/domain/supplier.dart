import 'package:flutter/material.dart';

@immutable
class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    this.category,
    this.phone,
    this.email,
    this.notes,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String? category;
  final String? phone;
  final String? email;
  final String? notes;
  final bool isActive;

  factory Supplier.fromMap(Map<String, dynamic> map) => Supplier(
        id: map['id'] as String,
        name: (map['name'] as String?) ?? '',
        category: map['category'] as String?,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        notes: map['notes'] as String?,
        isActive: (map['is_active'] as bool?) ?? true,
      );

  Map<String, dynamic> toWriteMap() => {
        'name': name,
        'category': category,
        'phone': phone,
        'email': email,
        'notes': notes,
        'is_active': isActive,
      };
}
