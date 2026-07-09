import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Formateadores centralizados en español de Argentina.
class Fmt {
  const Fmt._();

  static final NumberFormat _money = NumberFormat.currency(
    locale: 'es_AR',
    symbol: r'$',
    decimalDigits: 0,
  );

  static final DateFormat _date = DateFormat('dd/MM/yyyy', 'es_AR');
  static final DateFormat _dayMonth = DateFormat('EEE d MMM', 'es_AR');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy', 'es_AR');

  static final NumberFormat _usd = NumberFormat.currency(
    locale: 'es_AR',
    symbol: 'USD ',
    decimalDigits: 0,
  );

  /// $12.345 — pensado para pesos, sin decimales.
  static String money(num value) => _money.format(value);

  /// USD 1.000 — valor en dólares, sin decimales.
  static String usd(num value) => _usd.format(value);

  static String date(DateTime d) => _date.format(d);
  static String dayMonth(DateTime d) => _dayMonth.format(d);

  /// "julio 2026" con la primera letra en mayúscula.
  static String monthYear(DateTime d) {
    final raw = _monthYear.format(d);
    return raw.isEmpty ? raw : raw[0].toUpperCase() + raw.substring(1);
  }

  /// "14:30" a partir de un TimeOfDay.
  static String time(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Convierte "14:30:00" (Postgres time) a TimeOfDay. null si viene vacío.
  static TimeOfDay? parseTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  /// TimeOfDay -> "14:30:00" para guardar en Postgres.
  static String? serializeTime(TimeOfDay? t) =>
      t == null ? null : '${time(t)}:00';
}
