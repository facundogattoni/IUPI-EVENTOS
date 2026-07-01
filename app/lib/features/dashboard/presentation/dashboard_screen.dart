import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../application/dashboard_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(dashboardMonthProvider);
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final prevAsync = ref.watch(previousMonthSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardSummaryProvider);
          ref.invalidate(previousMonthSummaryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _MonthSelector(
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
              data: (s) => _SummaryContent(
                summary: s,
                previous: prevAsync.valueOrNull,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector(
      {required this.month, required this.onPrev, required this.onNext});
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton.filledTonal(
            onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
        Text(Fmt.monthYear(month),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        IconButton.filledTonal(
            onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ],
    );
  }
}

class _SummaryContent extends StatelessWidget {
  const _SummaryContent({required this.summary, required this.previous});
  final MonthlySummary summary;
  final MonthlySummary? previous;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: [
          Expanded(
            child: _MetricCard(
              label: 'Facturación',
              value: Fmt.money(summary.income),
              icon: Icons.trending_up,
              color: Colors.green,
              delta: _delta(summary.income, previous?.income),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricCard(
              label: 'Gastos',
              value: Fmt.money(summary.expenses),
              icon: Icons.trending_down,
              color: Colors.redAccent,
              delta: _delta(summary.expenses, previous?.expenses,
                  lowerIsBetter: true),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _MetricCard(
              label: 'Ganancia estimada',
              value: Fmt.money(summary.profit),
              icon: Icons.savings_outlined,
              color: summary.profit >= 0
                  ? Theme.of(context).colorScheme.primary
                  : Colors.redAccent,
              delta: _delta(summary.profit, previous?.profit),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricCard(
              label: 'Cumpleaños',
              value: '${summary.eventCount}',
              icon: Icons.cake_outlined,
              color: Colors.orange,
              delta: previous == null
                  ? null
                  : _intDelta(summary.eventCount, previous!.eventCount),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _OccupancyCard(summary: summary),
        if (summary.expenseByCategory.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ExpenseBreakdown(summary: summary),
        ],
      ],
    );
  }

  String? _delta(double current, double? prev, {bool lowerIsBetter = false}) {
    if (prev == null || prev == 0) return null;
    final pct = ((current - prev) / prev.abs()) * 100;
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(0)}% vs mes ant.';
  }

  String _intDelta(int current, int prev) {
    final diff = current - prev;
    final sign = diff >= 0 ? '+' : '';
    return '$sign$diff vs mes ant.';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.delta,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? delta;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800)),
            if (delta != null) ...[
              const SizedBox(height: 2),
              Text(delta!,
                  style:
                      TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

class _OccupancyCard extends StatelessWidget {
  const _OccupancyCard({required this.summary});
  final MonthlySummary summary;

  @override
  Widget build(BuildContext context) {
    final pct = (summary.occupancy * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_available, size: 20),
                const SizedBox(width: 8),
                const Text('Ocupación del salón',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('$pct%',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: summary.occupancy.clamp(0, 1),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 6),
            Text('${summary.occupiedDays} de ${summary.daysInMonth} días con eventos',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ExpenseBreakdown extends StatelessWidget {
  const _ExpenseBreakdown({required this.summary});
  final MonthlySummary summary;

  @override
  Widget build(BuildContext context) {
    final entries = summary.expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = summary.expenses;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gastos por categoría',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(e.key)),
                    Expanded(
                      flex: 5,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: total == 0 ? 0 : e.value / total,
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(Fmt.money(e.value),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.lock_outline, color: scheme.onSurfaceVariant, size: 40),
          const SizedBox(height: 12),
          Text(
            'No se pudo cargar el resumen.\nEl dashboard es solo para administradores.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text('$error',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
