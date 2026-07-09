import 'package:flutter/material.dart';

/// Inversión / bien de capital (inflable, horno, aire, juegos, mobiliario...).
/// Se amortiza en su vida útil. El valor en USD se congela con el dólar de la compra.
@immutable
class CapitalAsset {
  const CapitalAsset({
    required this.id,
    required this.name,
    required this.purchaseDate,
    required this.costArs,
    required this.usefulLifeMonths,
    this.category,
    this.usdRate,
    this.notes,
    this.isActive = true,
  });

  final String id;
  final String name;
  final DateTime purchaseDate;
  final double costArs;
  final int usefulLifeMonths;
  final String? category;
  final double? usdRate;
  final String? notes;
  final bool isActive;

  /// Valor en dólares al momento de la compra (congelado).
  double? get costUsd =>
      (usdRate != null && usdRate! > 0) ? costArs / usdRate! : null;

  double get monthlyDepreciation =>
      usefulLifeMonths == 0 ? 0 : costArs / usefulLifeMonths;

  /// Meses transcurridos desde la compra (tope: vida útil).
  int get monthsElapsed {
    final now = DateTime.now();
    final m = (now.year - purchaseDate.year) * 12 +
        (now.month - purchaseDate.month);
    if (m < 0) return 0;
    return m > usefulLifeMonths ? usefulLifeMonths : m;
  }

  double get accumulatedDepreciation => monthlyDepreciation * monthsElapsed;

  /// Valor contable actual (lo que "queda" del bien).
  double get bookValue => (costArs - accumulatedDepreciation).clamp(0, costArs);

  int get remainingMonths => usefulLifeMonths - monthsElapsed;

  /// Porcentaje amortizado (0..1).
  double get progress =>
      usefulLifeMonths == 0 ? 1 : monthsElapsed / usefulLifeMonths;

  bool get fullyAmortized => remainingMonths <= 0;

  factory CapitalAsset.fromMap(Map<String, dynamic> map) => CapitalAsset(
        id: map['id'] as String,
        name: (map['name'] as String?) ?? '',
        purchaseDate: DateTime.parse(map['purchase_date'] as String),
        costArs: (map['cost_ars'] as num).toDouble(),
        usefulLifeMonths: (map['useful_life_months'] as num?)?.toInt() ?? 60,
        category: map['category'] as String?,
        usdRate: (map['usd_rate'] as num?)?.toDouble(),
        notes: map['notes'] as String?,
        isActive: (map['is_active'] as bool?) ?? true,
      );

  Map<String, dynamic> toWriteMap() => {
        'name': name,
        'category': category,
        'purchase_date':
            '${purchaseDate.year.toString().padLeft(4, '0')}-${purchaseDate.month.toString().padLeft(2, '0')}-${purchaseDate.day.toString().padLeft(2, '0')}',
        'cost_ars': costArs,
        'usd_rate': usdRate,
        'useful_life_months': usefulLifeMonths,
        'notes': notes,
        'is_active': isActive,
      };
}

const kAssetCategories = <String>[
  'inflable',
  'horno',
  'aire',
  'juegos',
  'mobiliario',
  'cocina',
  'sonido',
  'otro',
];
