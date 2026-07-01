import 'package:flutter/material.dart';

@immutable
class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.name,
    this.category,
    this.quantity = 0,
    this.minQuantity = 0,
    this.unit,
    this.notes,
  });

  final String id;
  final String name;
  final String? category;
  final double quantity;
  final double minQuantity;
  final String? unit;
  final String? notes;

  bool get isLow => quantity <= minQuantity;

  String get quantityLabel {
    final q = quantity == quantity.roundToDouble()
        ? quantity.toStringAsFixed(0)
        : quantity.toStringAsFixed(1);
    return unit == null ? q : '$q ${unit!}';
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) => InventoryItem(
        id: map['id'] as String,
        name: (map['name'] as String?) ?? '',
        category: map['category'] as String?,
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
        minQuantity: (map['min_quantity'] as num?)?.toDouble() ?? 0,
        unit: map['unit'] as String?,
        notes: map['notes'] as String?,
      );

  Map<String, dynamic> toWriteMap() => {
        'name': name,
        'category': category,
        'quantity': quantity,
        'min_quantity': minQuantity,
        'unit': unit,
        'notes': notes,
      };
}
