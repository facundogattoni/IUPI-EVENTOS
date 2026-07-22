import 'package:flutter/material.dart';

/// Configuración de rentabilidad (una sola fila en la base).
@immutable
class BusinessSettings {
  const BusinessSettings({
    this.figurativeRentUsd = 0,
    this.fixedCostsMonthly = 0,
    this.variableCostPerEvent = 0,
    this.profitGoalMonthly = 0,
    this.alreadyRecoveredArs = 0,
  });

  final double figurativeRentUsd; // alquiler figurativo (costo de oportunidad)
  final double fixedCostsMonthly; // costos fijos mensuales estimados
  final double variableCostPerEvent; // costo variable por cumpleaños
  final double profitGoalMonthly; // meta de ganancia mensual
  final double alreadyRecoveredArs; // ya recuperado de la inversión (estimado)

  factory BusinessSettings.fromMap(Map<String, dynamic> map) => BusinessSettings(
        figurativeRentUsd:
            (map['figurative_rent_usd'] as num?)?.toDouble() ?? 0,
        fixedCostsMonthly:
            (map['fixed_costs_monthly'] as num?)?.toDouble() ?? 0,
        variableCostPerEvent:
            (map['variable_cost_per_event'] as num?)?.toDouble() ?? 0,
        profitGoalMonthly:
            (map['profit_goal_monthly'] as num?)?.toDouble() ?? 0,
        alreadyRecoveredArs:
            (map['already_recovered_ars'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toWriteMap() => {
        'figurative_rent_usd': figurativeRentUsd,
        'fixed_costs_monthly': fixedCostsMonthly,
        'variable_cost_per_event': variableCostPerEvent,
        'profit_goal_monthly': profitGoalMonthly,
        'already_recovered_ars': alreadyRecoveredArs,
      };
}
