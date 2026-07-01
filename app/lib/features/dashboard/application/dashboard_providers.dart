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
