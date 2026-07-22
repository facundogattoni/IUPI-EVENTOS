import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../application/rentabilidad_providers.dart';
import '../data/accounting_repository.dart';
import '../domain/business_settings.dart';

/// Rentabilidad: ganancia real, ROI de inversiones, calculadora y asesor.
class RentabilidadScreen extends ConsumerWidget {
  const RentabilidadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(dashboardMonthProvider);
    final async = ref.watch(profitabilityProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(profitabilityProvider);
        ref.invalidate(businessSettingsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: () => ref.read(dashboardMonthProvider.notifier).state =
                    DateTime(month.year, month.month - 1, 1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(Fmt.monthYear(month),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => ref.read(dashboardMonthProvider.notifier).state =
                    DateTime(month.year, month.month + 1, 1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _showSettings(context, ref),
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Configurar (alquiler figurativo, costos, meta)'),
          ),
          const SizedBox(height: 16),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Solo administradores pueden ver la rentabilidad.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            data: (p) => Column(
              children: [
                _RealProfitCard(p: p),
                const SizedBox(height: 12),
                _AdvisorCard(p: p),
                const SizedBox(height: 12),
                _CalcCard(p: p),
                const SizedBox(height: 12),
                _RoiCard(p: p),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _showSettings(BuildContext context, WidgetRef ref) async {
    final s = await ref.read(accountingRepositoryProvider).fetchSettings();
    if (!context.mounted) return;
    final rent = TextEditingController(
        text: s.figurativeRentUsd == 0 ? '' : s.figurativeRentUsd.toStringAsFixed(0));
    final fixed = TextEditingController(
        text: s.fixedCostsMonthly == 0 ? '' : s.fixedCostsMonthly.toStringAsFixed(0));
    final variable = TextEditingController(
        text: s.variableCostPerEvent == 0 ? '' : s.variableCostPerEvent.toStringAsFixed(0));
    final goal = TextEditingController(
        text: s.profitGoalMonthly == 0 ? '' : s.profitGoalMonthly.toStringAsFixed(0));
    final recovered = TextEditingController(
        text: s.alreadyRecoveredArs == 0 ? '' : s.alreadyRecoveredArs.toStringAsFixed(0));

    double d(TextEditingController c) =>
        double.tryParse(c.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Configuración de rentabilidad',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: rent,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Alquiler figurativo (USD/mes)',
                  helperText: 'Lo que ganarías si alquilaras el salón (ej: 1300)',
                  prefixText: 'USD ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: fixed,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Costos fijos mensuales (\$)',
                  helperText: 'Sueldos base, servicios, etc. (para la calculadora)',
                  prefixText: r'$ ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: variable,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Costo variable por cumple (\$)',
                  helperText: 'Comida, descartables, animación por evento',
                  prefixText: r'$ ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: goal,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Meta de ganancia mensual (\$)',
                  prefixText: r'$ ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: recovered,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Ya recuperado de la inversión (estimado, \$)',
                  helperText: 'Aprox. de lo que ya te dejó la actividad anterior',
                  prefixText: r'$ ',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  await ref.read(accountingRepositoryProvider).updateSettings(
                        BusinessSettings(
                          figurativeRentUsd: d(rent),
                          fixedCostsMonthly: d(fixed),
                          variableCostPerEvent: d(variable),
                          profitGoalMonthly: d(goal),
                          alreadyRecoveredArs: d(recovered),
                        ),
                      );
                  ref.invalidate(businessSettingsProvider);
                  ref.invalidate(profitabilityProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _card({required Widget child}) => Builder(
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      ),
    );

class _RealProfitCard extends StatelessWidget {
  const _RealProfitCard({required this.p});
  final Profitability p;

  @override
  Widget build(BuildContext context) {
    final positive = p.realProfit >= 0;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ganancia REAL del mes',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(Fmt.money(p.realProfit),
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: positive ? AppColors.income : AppColors.danger)),
          if (p.realProfitUsd != null)
            Text(Fmt.usd(p.realProfitUsd!),
                style: const TextStyle(color: AppColors.textMuted)),
          const Divider(height: 24),
          _line('Facturación', p.income, AppColors.income, sign: '+'),
          _line('Gastos', p.expenses, AppColors.expense, sign: '−'),
          _line('Amortización inversiones', p.amortization, AppColors.expense,
              sign: '−'),
          _line('Alquiler figurativo', p.figurativeRentArs, AppColors.expense,
              sign: '−'),
          const SizedBox(height: 6),
          Text(
            positive
                ? '✅ El negocio le gana a alquilar el salón.'
                : '⚠️ Hoy te convendría alquilar el salón.',
            style: TextStyle(
                fontSize: 12,
                color: positive ? AppColors.income : AppColors.danger),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, double value, Color color, {required String sign}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text('$sign ${Fmt.money(value)}',
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _AdvisorCard extends StatelessWidget {
  const _AdvisorCard({required this.p});
  final Profitability p;

  @override
  Widget build(BuildContext context) {
    final insights = p.insights;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.auto_awesome_rounded, color: AppColors.gold, size: 20),
              SizedBox(width: 8),
              Text('Asesor inteligente',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          if (insights.isEmpty)
            const Text('Cargá cumples, gastos y el dólar para ver sugerencias.',
                style: TextStyle(color: AppColors.textMuted))
          else
            for (final i in insights)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_icon(i.tone), size: 18, color: _color(i.tone)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(i.text)),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  IconData _icon(InsightTone t) {
    switch (t) {
      case InsightTone.good:
        return Icons.check_circle_rounded;
      case InsightTone.warn:
        return Icons.warning_amber_rounded;
      case InsightTone.info:
        return Icons.lightbulb_outline_rounded;
    }
  }

  Color _color(InsightTone t) {
    switch (t) {
      case InsightTone.good:
        return AppColors.income;
      case InsightTone.warn:
        return AppColors.danger;
      case InsightTone.info:
        return AppColors.info;
    }
  }
}

class _CalcCard extends StatelessWidget {
  const _CalcCard({required this.p});
  final Profitability p;

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Calculadora',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _row('Punto de equilibrio',
              p.breakEvenEvents == null ? '—' : '${p.breakEvenEvents} cumples/mes'),
          _row('Para tu meta',
              p.eventsForGoal == null ? '—' : '${p.eventsForGoal} cumples/mes'),
          _row('Precio promedio actual',
              p.avgPrice == 0 ? '—' : Fmt.money(p.avgPrice)),
          _row('Precio sugerido',
              p.suggestedPrice == null ? '—' : Fmt.money(p.suggestedPrice!),
              highlight: true),
          const SizedBox(height: 6),
          const Text(
            'Configurá costos fijos, costo por cumple y meta para afinar estos números.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: AppColors.textMuted))),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: highlight ? AppColors.brand : AppColors.textStrong)),
        ],
      ),
    );
  }
}

class _RoiCard extends StatelessWidget {
  const _RoiCard({required this.p});
  final Profitability p;

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Retorno de inversión (ROI)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _mini('Total invertido', Fmt.money(p.totalInvestedArs),
                    p.totalInvestedUsd > 0 ? Fmt.usd(p.totalInvestedUsd) : null),
              ),
              Expanded(
                child: _mini('Amortización/mes',
                    Fmt.money(p.amortization), null),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _mini('Ya recuperado (est.)',
                    Fmt.money(p.settings.alreadyRecoveredArs), null),
              ),
              Expanded(
                child: _mini(
                    'Falta recuperar', Fmt.money(p.pendingToRecover), null),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _mini(
                    'Se recupera en',
                    p.pendingToRecover <= 0
                        ? '¡Listo!'
                        : (p.paybackMonths == null
                            ? '—'
                            : '${p.paybackMonths} meses'),
                    null),
              ),
              Expanded(
                child: _mini(
                    'ROI anual estimado',
                    p.annualRoiPct == null
                        ? '—'
                        : '${p.annualRoiPct!.toStringAsFixed(0)}%',
                    null),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(String label, String value, String? sub) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800)),
          if (sub != null)
            Text(sub,
                style: const TextStyle(fontSize: 12, color: AppColors.income)),
        ],
      );
}
