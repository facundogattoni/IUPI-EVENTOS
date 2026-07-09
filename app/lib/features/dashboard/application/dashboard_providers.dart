import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../events/data/event_repository.dart';
import '../../events/domain/event_status.dart';
import '../../finance/data/finance_repository.dart';
import '../../finance/domain/transaction.dart';

/// Resumen de un mes para el dashboard.
class MonthlySummary {
  const MonthlySummary({
    required this.month,
    required this.income,
    required this.expenses,
    required this.eventCount,
    required this.occupiedDays,
    required this.daysInMonth,
    required this.expenseByCategory,
  });

  final DateTime month;
  final double income;
  final double expenses;
  final int eventCount;
  final int occupiedDays;
  final int daysInMonth;
  final Map<String, double> expenseByCategory;

  double get profit => income - expenses;
  double get occupancy => daysInMonth == 0 ? 0 : occupiedDays / daysInMonth;
}

/// Mes seleccionado en el dashboard (siempre el día 1).
final dashboardMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

DateTime _firstOf(DateTime m) => DateTime(m.year, m.month, 1);
DateTime _lastOf(DateTime m) => DateTime(m.year, m.month + 1, 0);

Future<MonthlySummary> _summaryFor(Ref ref, DateTime month) async {
  final from = _firstOf(month);
  final to = _lastOf(month);

  final txs = await ref.read(financeRepositoryProvider).fetchInRange(from, to);
  final events = await ref.read(eventRepositoryProvider).fetchInRange(from, to);

  double income = 0, expenses = 0;
  final byCategory = <String, double>{};
  for (final t in txs) {
    if (t.type == TxType.ingreso) {
      income += t.amount;
    } else {
      expenses += t.amount;
      byCategory.update(t.category, (v) => v + t.amount,
          ifAbsent: () => t.amount);
    }
  }

  final active =
      events.where((e) => e.status != EventStatus.cancelado).toList();
  final occupiedDays =
      active.map((e) => e.eventDate.day).toSet().length;

  return MonthlySummary(
    month: month,
    income: income,
    expenses: expenses,
    eventCount: active.length,
    occupiedDays: occupiedDays,
    daysInMonth: to.day,
    expenseByCategory: byCategory,
  );
}

/// Resumen del mes seleccionado.
final dashboardSummaryProvider = FutureProvider<MonthlySummary>((ref) async {
  final month = ref.watch(dashboardMonthProvider);
  return _summaryFor(ref, month);
});

/// Resumen del mes anterior (para comparar).
final previousMonthSummaryProvider =
    FutureProvider<MonthlySummary>((ref) async {
  final month = ref.watch(dashboardMonthProvider);
  final prev = DateTime(month.year, month.month - 1, 1);
  return _summaryFor(ref, prev);
});

/// Un punto de la serie mensual (para el gráfico de barras).
class MonthPoint {
  const MonthPoint(this.month, this.income, this.expense);
  final DateTime month;
  final double income;
  final double expense;
}

/// Ingresos y gastos de los últimos 6 meses (terminando en el mes elegido).
final sixMonthSeriesProvider = FutureProvider<List<MonthPoint>>((ref) async {
  final anchor = ref.watch(dashboardMonthProvider);
  final start = DateTime(anchor.year, anchor.month - 5, 1);
  final end = DateTime(anchor.year, anchor.month + 1, 0);
  final txs = await ref.read(financeRepositoryProvider).fetchInRange(start, end);

  final buckets = <DateTime, List<double>>{};
  for (var i = 0; i < 6; i++) {
    final m = DateTime(anchor.year, anchor.month - 5 + i, 1);
    buckets[m] = [0, 0];
  }
  for (final t in txs) {
    final key = DateTime(t.occurredOn.year, t.occurredOn.month, 1);
    final b = buckets[key];
    if (b == null) continue;
    if (t.type == TxType.ingreso) {
      b[0] += t.amount;
    } else {
      b[1] += t.amount;
    }
  }
  final entries = buckets.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return [for (final e in entries) MonthPoint(e.key, e.value[0], e.value[1])];
});

/// Total pendiente de cobro (saldos de eventos no cancelados en un rango amplio).
final pendingBalanceProvider = FutureProvider<double>((ref) async {
  ref.watch(dashboardMonthProvider);
  final now = DateTime.now();
  final from = DateTime(now.year, now.month - 3, 1);
  final to = DateTime(now.year, now.month + 6, 0);
  final events = await ref.read(eventRepositoryProvider).fetchInRange(from, to);
  double total = 0;
  for (final e in events) {
    if (e.status == EventStatus.cancelado) continue;
    total += e.balanceDue;
  }
  return total;
});
