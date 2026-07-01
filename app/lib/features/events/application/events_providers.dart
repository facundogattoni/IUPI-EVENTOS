import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../data/event_repository.dart';
import '../domain/event.dart';
import '../domain/payment.dart';

/// Normaliza una fecha a su día (sin hora), para usar como clave estable.
DateTime dayKey(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// Formato actual del calendario (mes / semana / día simulado con 2 semanas...).
final calendarFormatProvider =
    StateProvider<CalendarFormat>((ref) => CalendarFormat.month);

/// Día seleccionado (para la lista inferior y el alta rápida).
final selectedDayProvider = StateProvider<DateTime>((ref) => dayKey(DateTime.now()));

/// Día en foco del calendario (define el mes que se carga).
final focusedDayProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// Carga los eventos del mes en foco (con margen para llenar la grilla) y los
/// agrupa por día. Se refresca al cambiar de mes o al invalidar tras editar.
final monthEventsProvider =
    FutureProvider<Map<DateTime, List<Event>>>((ref) async {
  final focused = ref.watch(focusedDayProvider);
  final from = DateTime(focused.year, focused.month, 1)
      .subtract(const Duration(days: 7));
  final to = DateTime(focused.year, focused.month + 1, 0)
      .add(const Duration(days: 7));

  final events = await ref.watch(eventRepositoryProvider).fetchInRange(from, to);

  final grouped = <DateTime, List<Event>>{};
  for (final e in events) {
    grouped.putIfAbsent(dayKey(e.eventDate), () => []).add(e);
  }
  return grouped;
});

/// Eventos de un día puntual (deriva del mes ya cargado).
final eventsOfDayProvider = Provider.family<List<Event>, DateTime>((ref, day) {
  final grouped = ref.watch(monthEventsProvider).valueOrNull ?? {};
  return grouped[dayKey(day)] ?? const [];
});

/// Detalle de un evento (recarga staff y saldo).
final eventDetailProvider =
    FutureProvider.family<Event?, String>((ref, id) async {
  return ref.watch(eventRepositoryProvider).fetchById(id);
});

/// Pagos de un evento.
final eventPaymentsProvider =
    FutureProvider.family<List<Payment>, String>((ref, eventId) async {
  return ref.watch(eventRepositoryProvider).fetchPayments(eventId);
});
