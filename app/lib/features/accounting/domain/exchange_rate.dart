import 'package:flutter/material.dart';

/// Cotización del dólar cargada para una fecha (pesos por 1 USD).
@immutable
class ExchangeRate {
  const ExchangeRate({
    required this.id,
    required this.rateDate,
    required this.usdArs,
  });

  final String id;
  final DateTime rateDate;
  final double usdArs;

  factory ExchangeRate.fromMap(Map<String, dynamic> map) => ExchangeRate(
        id: map['id'] as String,
        rateDate: DateTime.parse(map['rate_date'] as String),
        usdArs: (map['usd_ars'] as num).toDouble(),
      );
}
