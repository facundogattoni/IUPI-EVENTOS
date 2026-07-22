import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../events/data/event_repository.dart';
import '../../events/domain/event_status.dart';
import '../data/accounting_repository.dart';
import '../domain/business_settings.dart';

enum InsightTone { good, warn, info }

class Insight {
  const Insight(this.tone, this.text);
  final InsightTone tone;
  final String text;
}

/// Todos los números de rentabilidad del mes elegido + sugerencias del asesor.
class Profitability {
  Profitability({
    required this.income,
    required this.expenses,
    required this.eventCount,
    required this.occupancy,
    required this.amortization,
    required this.figurativeRentArs,
    required this.usdRate,
    required this.avgPrice,
    required this.totalLaborHours,
    required this.totalInvestedArs,
    required this.totalInvestedUsd,
    required this.settings,
    required this.expenseByCategory,
  });

  final double income;
  final double expenses;
  final int eventCount;
  final double occupancy;
  final double amortization; // amortización mensual de las inversiones
  final double figurativeRentArs; // alquiler figurativo en pesos
  final double? usdRate;
  final double avgPrice; // precio promedio de los cumples del mes
  final double totalLaborHours;
  final double totalInvestedArs;
  final double totalInvestedUsd;
  final BusinessSettings settings;
  final Map<String, double> expenseByCategory;

  /// Ganancia contable simple (sin amortización ni alquiler figurativo).
  double get operatingProfit => income - expenses;

  /// Ganancia REAL: descuenta amortizaciones y el costo de oportunidad del local.
  double get realProfit =>
      income - expenses - amortization - figurativeRentArs;

  double? get realProfitUsd =>
      (usdRate != null && usdRate! > 0) ? realProfit / usdRate! : null;

  double? get profitPerHour =>
      totalLaborHours > 0 ? realProfit / totalLaborHours : null;

  double get fixedTotalPlan =>
      settings.fixedCostsMonthly + amortization + figurativeRentArs;

  double get contribution => avgPrice - settings.variableCostPerEvent;

  int? get breakEvenEvents => contribution > 0
      ? (fixedTotalPlan / contribution).ceil()
      : null;

  int? get eventsForGoal => contribution > 0
      ? ((fixedTotalPlan + settings.profitGoalMonthly) / contribution).ceil()
      : null;

  double? get suggestedPrice {
    final n = eventCount > 0 ? eventCount : (breakEvenEvents ?? 0);
    if (n <= 0) return null;
    return (fixedTotalPlan + settings.profitGoalMonthly) / n +
        settings.variableCostPerEvent;
  }

  /// Cuánto falta recuperar (total invertido menos lo ya recuperado estimado).
  double get pendingToRecover =>
      (totalInvestedArs - settings.alreadyRecoveredArs).clamp(0, totalInvestedArs);

  int? get paybackMonths => (realProfit > 0 && pendingToRecover > 0)
      ? (pendingToRecover / realProfit).ceil()
      : null;

  /// ROI anual estimado sobre la inversión (ganancia real x12 / invertido).
  double? get annualRoiPct => totalInvestedArs > 0
      ? (realProfit * 12 / totalInvestedArs) * 100
      : null;

  /// Sugerencias del "asesor inteligente" (reglas de negocio).
  List<Insight> get insights {
    final out = <Insight>[];

    if (realProfit >= 0) {
      out.add(Insight(InsightTone.good,
          'Ganás ${Fmt.money(realProfit)} reales este mes (ya descontando amortizaciones y el alquiler figurativo).'));
    } else {
      out.add(Insight(InsightTone.warn,
          'Estás ${Fmt.money(realProfit.abs())} en rojo real: hoy te convendría alquilar el salón. Subí precios, sumá cumples o bajá costos.'));
    }

    if (breakEvenEvents != null) {
      final be = breakEvenEvents!;
      final tone = eventCount >= be ? InsightTone.good : InsightTone.warn;
      out.add(Insight(tone,
          'Necesitás $be cumple(s) al mes para no perder. Este mes vas $eventCount.'));
    } else if (avgPrice > 0) {
      out.add(const Insight(InsightTone.warn,
          'El costo variable por cumple es mayor o igual al precio: revisá esos números.'));
    }

    if (suggestedPrice != null && avgPrice > 0) {
      if (suggestedPrice! > avgPrice * 1.05) {
        out.add(Insight(InsightTone.warn,
            'Para tu meta de ganancia, el precio sugerido es ${Fmt.money(suggestedPrice!)} por cumple (hoy promediás ${Fmt.money(avgPrice)}).'));
      } else {
        out.add(Insight(InsightTone.good,
            'Tu precio promedio (${Fmt.money(avgPrice)}) ya alcanza para tu meta. 👌'));
      }
    }

    if (profitPerHour != null) {
      out.add(Insight(InsightTone.info,
          'Cada hora de trabajo te deja ${Fmt.money(profitPerHour!)} (sobre ${totalLaborHours.toStringAsFixed(0)} hs este mes).'));
    }

    if (totalInvestedArs > 0 && pendingToRecover <= 0) {
      out.add(const Insight(InsightTone.good,
          'Ya recuperaste toda la inversión. De acá en más es ganancia neta. 🎉'));
    } else if (paybackMonths != null) {
      out.add(Insight(InsightTone.info,
          'Te falta recuperar ${Fmt.money(pendingToRecover)} de la inversión; al ritmo actual lo recuperás en ~$paybackMonths meses.'));
    }

    // Categoría de gasto más pesada.
    if (expenseByCategory.isNotEmpty && expenses > 0) {
      final top = expenseByCategory.entries
          .reduce((a, b) => a.value >= b.value ? a : b);
      final share = top.value / expenses;
      if (share > 0.4) {
        out.add(Insight(InsightTone.info,
            'El ${(share * 100).round()}% de tus gastos es "${top.key}". Si lo bajás 10%, ganás ${Fmt.money(top.value * 0.1)} más.'));
      }
    }

    if (occupancy < 0.3 && eventCount > 0) {
      out.add(const Insight(InsightTone.info,
          'Ocupás pocos días del mes: con más cumples repartís los costos fijos y sube la ganancia por evento.'));
    }

    return out;
  }
}

final profitabilityProvider = FutureProvider<Profitability>((ref) async {
  final month = ref.watch(dashboardMonthProvider);
  final summary = await ref.watch(dashboardSummaryProvider.future);
  final assets = await ref.watch(assetsProvider.future);
  final settings = await ref.watch(businessSettingsProvider.future);
  final rate = await ref.watch(latestRateProvider.future);

  final from = DateTime(month.year, month.month, 1);
  final to = DateTime(month.year, month.month + 1, 0);
  final events = await ref.read(eventRepositoryProvider).fetchInRange(from, to);
  final active =
      events.where((e) => e.status != EventStatus.cancelado).toList();

  final priced = active.where((e) => e.price > 0).toList();
  final avgPrice = priced.isEmpty
      ? 0.0
      : priced.fold<double>(0, (s, e) => s + e.price) / priced.length;
  final totalHours =
      active.fold<double>(0, (s, e) => s + (e.laborHours ?? 0));

  final amortization = assets
      .where((a) => !a.fullyAmortized)
      .fold<double>(0, (s, a) => s + a.monthlyDepreciation);
  final investedArs = assets.fold<double>(0, (s, a) => s + a.costArs);
  final investedUsd = assets.fold<double>(0, (s, a) => s + (a.costUsd ?? 0));

  final rateVal = rate?.usdArs;
  final figurativeArs =
      rateVal != null ? settings.figurativeRentUsd * rateVal : 0.0;

  return Profitability(
    income: summary.income,
    expenses: summary.expenses,
    eventCount: summary.eventCount,
    occupancy: summary.occupancy,
    amortization: amortization,
    figurativeRentArs: figurativeArs,
    usdRate: rateVal,
    avgPrice: avgPrice,
    totalLaborHours: totalHours,
    totalInvestedArs: investedArs,
    totalInvestedUsd: investedUsd,
    settings: settings,
    expenseByCategory: summary.expenseByCategory,
  );
});
