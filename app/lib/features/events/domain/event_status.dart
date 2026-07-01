import 'package:flutter/material.dart';

/// Estado del ciclo de vida de un cumpleaños. Debe coincidir con el enum
/// event_status de la base (0001_init.sql).
enum EventStatus {
  presupuestado,
  reservado,
  confirmado,
  completado,
  cancelado;

  static EventStatus fromDb(String? value) {
    return EventStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => EventStatus.presupuestado,
    );
  }

  String get db => name;

  String get label {
    switch (this) {
      case EventStatus.presupuestado:
        return 'Presupuestado';
      case EventStatus.reservado:
        return 'Reservado';
      case EventStatus.confirmado:
        return 'Confirmado';
      case EventStatus.completado:
        return 'Completado';
      case EventStatus.cancelado:
        return 'Cancelado';
    }
  }

  Color color(ColorScheme scheme) {
    switch (this) {
      case EventStatus.presupuestado:
        return Colors.blueGrey;
      case EventStatus.reservado:
        return Colors.orange;
      case EventStatus.confirmado:
        return Colors.green;
      case EventStatus.completado:
        return scheme.primary;
      case EventStatus.cancelado:
        return scheme.error;
    }
  }
}
