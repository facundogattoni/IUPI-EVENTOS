import 'package:flutter/material.dart';

enum TxType {
  ingreso,
  gasto;

  static TxType fromDb(String? v) =>
      v == 'ingreso' ? TxType.ingreso : TxType.gasto;
  String get db => name;
  String get label => this == TxType.ingreso ? 'Ingreso' : 'Gasto';
  bool get isIncome => this == TxType.ingreso;
}

/// Categorías sugeridas para clasificar ingresos y gastos.
const kIncomeCategories = <String>[
  'Pago de evento',
  'Seña',
  'Otros ingresos',
];
const kExpenseCategories = <String>[
  'Alquiler',
  'Sueldos',
  'Comida',
  'Bebidas',
  'Servicios',
  'Limpieza',
  'Mantenimiento',
  'Compras',
  'Decoración',
  'Impuestos',
  'Otros gastos',
];

@immutable
class Transaction {
  const Transaction({
    required this.id,
    required this.type,
    required this.category,
    required this.amount,
    required this.occurredOn,
    this.description,
    this.eventId,
    this.supplierId,
  });

  final String id;
  final TxType type;
  final String category;
  final double amount;
  final DateTime occurredOn;
  final String? description;
  final String? eventId;
  final String? supplierId;

  /// Con signo: negativo para gastos. Útil para sumar el neto.
  double get signed => type.isIncome ? amount : -amount;

  factory Transaction.fromMap(Map<String, dynamic> map) => Transaction(
        id: map['id'] as String,
        type: TxType.fromDb(map['type'] as String?),
        category: (map['category'] as String?) ?? '',
        amount: (map['amount'] as num).toDouble(),
        occurredOn: DateTime.parse(map['occurred_on'] as String),
        description: map['description'] as String?,
        eventId: map['event_id'] as String?,
        supplierId: map['supplier_id'] as String?,
      );

  Map<String, dynamic> toWriteMap() => {
        'type': type.db,
        'category': category,
        'amount': amount,
        'occurred_on':
            '${occurredOn.year.toString().padLeft(4, '0')}-${occurredOn.month.toString().padLeft(2, '0')}-${occurredOn.day.toString().padLeft(2, '0')}',
        'description': description,
        'event_id': eventId,
        'supplier_id': supplierId,
      };
}
