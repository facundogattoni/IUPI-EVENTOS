import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../application/dashboard_providers.dart';

const _mesesCortos = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// Panel de control con métricas del negocio y gráficos.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(dashboardMonthProvider);
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final prev = ref.watch(previousMonthSummaryProvider).valueOrNull;
    final series = ref.watch(sixMonthSeriesProvider).valueOrNull ?? const [];
    final pending = ref.watch(pendingBalanceProvider).valueOrNull ?? 0;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardSummaryProvider);
        ref.invalidate(previousMonthSummaryProvider);
        ref.invalidate(sixMonthSeriesProvider);
        ref.invalidate(pendingBalanceProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PeriodSelector(
            month: month,
            onPrev: () => ref.read(dashboardMonthProvider.notifier).state =
                DateTime(month.year, month.month - 1, 1),
            onNext: () => ref.read(dashboardMonthProvider.notifier).state =
                DateTime(month.year, month.month + 1, 1),
          ),
          const SizedBox(height: 16),
          summaryAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => _ErrorBox(error: e),
            data: (s) => Column(
              children: [
                _StatGrid(summary: s, previous: prev, pending: pending),
                const SizedBox(height: 16),
                _ChartsRow(summary: s, series: series),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector(
      {required this.month, required this.onPrev, required this.onNext});
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.calendar_today_rounded,
              size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          const Text('Período', style: TextStyle(color: AppColors.textMuted)),
          const Spacer(),
          IconButton(
              onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
          Text(Fmt.monthYear(month),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
              onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({
    required this.summary,
    required this.previous,
    required this.pending,
  });
  final MonthlySummary summary;
  final MonthlySummary? previous;
  final double pending;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _StatCard(
        label: 'Facturación',
        value: Fmt.money(summary.income),
        icon: Icons.attach_money_rounded,
        color: AppColors.income,
        delta: _pctDelta(summary.income, previous?.income),
      ),
      _StatCard(
        label: 'Gastos',
        value: Fmt.money(summary.expenses),
        icon: Icons.receipt_long_rounded,
        color: AppColors.expense,
        delta: _pctDelta(summary.expenses, previous?.expenses),
      ),
      _StatCard(
        label: 'Ganancia',
        value: Fmt.money(summary.profit),
        icon: Icons.savings_rounded,
        color: summary.profit >= 0 ? AppColors.brand : AppColors.danger,
        delta: _pctDelta(summary.profit, previous?.profit),
      ),
      _StatCard(
        label: 'Cumpleaños',
        value: '${summary.eventCount}',
        icon: Icons.cake_rounded,
        color: AppColors.kids,
        delta: previous == null
            ? null
            : _intDelta(summary.eventCount, previous!.eventCount),
      ),
      _StatCard(
        label: 'Por cobrar',
        value: Fmt.money(pending),
        icon: Icons.error_outline_rounded,
        color: AppColors.danger,
        subtitle: 'saldos pendientes',
      ),
      _StatCard(
        label: 'Ocupación',
        value: '${(summary.occupancy * 100).round()}%',
        icon: Icons.event_available_rounded,
        color: AppColors.info,
        subtitle: '${summary.occupiedDays}/${summary.daysInMonth} días',
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth > 1000
            ? 3
            : c.maxWidth > 640
                ? 3
                : 2;
        const gap = 12.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final card in cards) SizedBox(width: w, child: card)],
        );
      },
    );
  }

  String? _pctDelta(double current, double? prev) {
    if (prev == null || prev == 0) return null;
    final pct = ((current - prev) / prev.abs()) * 100;
    return '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(0)}% vs mes ant.';
  }

  String _intDelta(int current, int prev) {
    final d = current - prev;
    return '${d >= 0 ? '+' : ''}$d vs mes ant.';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.delta,
    this.subtitle,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? delta;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted)),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w900, color: color)),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle ?? delta ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ChartsRow extends StatelessWidget {
  const _ChartsRow({required this.summary, required this.series});
  final MonthlySummary summary;
  final List<MonthPoint> series;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final bars = _ChartCard(
        title: 'Ingresos vs Gastos',
        subtitle: 'Últimos 6 meses',
        child: SizedBox(height: 220, child: _IncomeExpenseBars(series: series)),
      );
      final donut = _ChartCard(
        title: 'Gastos por categoría',
        subtitle: Fmt.monthYear(summary.month),
        child: SizedBox(
            height: 220, child: _ExpenseDonut(summary: summary)),
      );
      if (c.maxWidth > 800) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: bars),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: donut),
          ],
        );
      }
      return Column(children: [bars, const SizedBox(height: 12), donut]);
    });
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard(
      {required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800)),
          Text(subtitle,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _IncomeExpenseBars extends StatelessWidget {
  const _IncomeExpenseBars({required this.series});
  final List<MonthPoint> series;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return const Center(
          child: Text('Sin datos', style: TextStyle(color: AppColors.textMuted)));
    }
    double maxY = 0;
    for (final p in series) {
      maxY = [maxY, p.income, p.expense].reduce((a, b) => a > b ? a : b);
    }
    if (maxY == 0) maxY = 1;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceAlt,
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              Fmt.money(rod.toY),
              const TextStyle(color: AppColors.textStrong, fontSize: 11),
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= series.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_mesesCortos[series[i].month.month - 1],
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < series.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 3,
              barRods: [
                BarChartRodData(
                  toY: series[i].income,
                  color: AppColors.income,
                  width: 8,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3)),
                ),
                BarChartRodData(
                  toY: series[i].expense,
                  color: AppColors.expense,
                  width: 8,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ExpenseDonut extends StatelessWidget {
  const _ExpenseDonut({required this.summary});
  final MonthlySummary summary;

  static const _palette = [
    AppColors.expense,
    AppColors.brand,
    AppColors.info,
    AppColors.kids,
    AppColors.income,
    AppColors.gold,
  ];

  @override
  Widget build(BuildContext context) {
    final entries = summary.expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return const Center(
          child: Text('Sin gastos este mes',
              style: TextStyle(color: AppColors.textMuted)));
    }
    final total = summary.expenses;
    return Row(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 34,
              sectionsSpace: 2,
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value,
                    color: _palette[i % _palette.length],
                    radius: 18,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < entries.length && i < 6; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _palette[i % _palette.length],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(entries[i].key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12)),
                      ),
                      Text(
                        total == 0
                            ? '0%'
                            : '${(entries[i].value / total * 100).round()}%',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.lock_outline,
              color: AppColors.textMuted, size: 40),
          const SizedBox(height: 12),
          const Text(
            'No se pudo cargar el resumen.\nEl dashboard es solo para administradores.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          Text('$error',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
