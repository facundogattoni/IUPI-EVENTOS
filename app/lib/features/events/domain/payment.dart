import 'package:flutter/material.dart';

/// Un pago registrado de un evento (seña o saldo).
@immutable
class Payment {
  const Payment({
    required this.id,
    required this.eventId,
    required this.amount,
    required this.paidAt,
    this.method,
    this.note,
  });

  final String id;
  final String eventId;
  final double amount;
  final DateTime paidAt;
  final String? method;
  final String? note;

  factory Payment.fromMap(Map<String, dynamic> map) => Payment(
        id: map['id'] as String,
        eventId: map['event_id'] as String,
        amount: (map['amount'] as num).toDouble(),
        paidAt: DateTime.parse(map['paid_at'] as String),
        method: map['method'] as String?,
        note: map['note'] as String?,
      );
}
