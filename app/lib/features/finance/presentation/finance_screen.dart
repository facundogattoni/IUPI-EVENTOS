import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../application/finance_providers.dart';
import '../data/finance_repository.dart';
import '../domain/supplier.dart';
import '../domain/transaction.dart';

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: const Column(
        children: [
          Material(
            color: Colors.transparent,
            child: TabBar(
              tabs: [
                Tab(text: 'Movimientos'),
                Tab(text: 'Proveedores'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(children: [
              _TransactionsTab(),
              _SuppliersTab(),
            ]),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Movimientos
// =====================================================================
class _TransactionsTab extends ConsumerWidget {
  const _TransactionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(financeMonthProvider);
    final txAsync = ref.watch(transactionsProvider);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () =>
                      ref.read(financeMonthProvider.notifier).state =
                          DateTime(month.year, month.month - 1, 1),
                ),
                Text(Fmt.monthYear(month),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () =>
                      ref.read(financeMonthProvider.notifier).state =
                          DateTime(month.year, month.month + 1, 1),
                ),
              ],
            ),
          ),
          Expanded(
            child: txAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _LockedNotice(error: e),
              data: (txs) {
                if (txs.isEmpty) {
                  return const Center(
                      child: Text('Sin movimientos este mes.'));
                }
                final income = txs
                    .where((t) => t.type == TxType.ingreso)
                    .fold<double>(0, (s, t) => s + t.amount);
                final expenses = txs
                    .where((t) => t.type == TxType.gasto)
                    .fold<double>(0, (s, t) => s + t.amount);
                return Column(
                  children: [
                    _Totals(income: income, expenses: expenses),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(transactionsProvider),
                        child: ListView.builder(
                          itemCount: txs.length,
                          itemBuilder: (ctx, i) =>
                              _TxTile(tx: txs[i], ref: ref),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTx(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddTx(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AddTransactionSheet(),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.income, required this.expenses});
  final double income;
  final double expenses;

  @override
  Widget build(BuildContext context) {
    final net = income - expenses;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _pill(context, 'Ingresos', income, Colors.green),
          const SizedBox(width: 8),
          _pill(context, 'Gastos', expenses, Colors.redAccent),
          const SizedBox(width: 8),
          _pill(context, 'Neto', net,
              net >= 0 ? Theme.of(context).colorScheme.primary : Colors.redAccent),
        ],
      ),
    );
  }

  Widget _pill(BuildContext ctx, String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: color)),
            const SizedBox(height: 2),
            Text(Fmt.money(value),
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: color, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({required this.tx, required this.ref});
  final Transaction tx;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final income = tx.type == TxType.ingreso;
    final color = income ? Colors.green : Colors.redAccent;
    return Dismissible(
      key: ValueKey(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red.withValues(alpha: 0.15),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      confirmDismiss: (_) async {
        await ref.read(financeRepositoryProvider).deleteTransaction(tx.id);
        ref.invalidate(transactionsProvider);
        return true;
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(income ? Icons.south_west : Icons.north_east,
              color: color, size: 20),
        ),
        title: Text(tx.category),
        subtitle: Text(
            '${Fmt.date(tx.occurredOn)}${tx.description != null ? ' · ${tx.description}' : ''}'),
        trailing: Text(
          '${income ? '+' : '-'}${Fmt.money(tx.amount)}',
          style: TextStyle(fontWeight: FontWeight.w700, color: color),
        ),
      ),
    );
  }
}

class _AddTransactionSheet extends ConsumerStatefulWidget {
  const _AddTransactionSheet();

  @override
  ConsumerState<_AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<_AddTransactionSheet> {
  TxType _type = TxType.gasto;
  String _category = kExpenseCategories.first;
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  List<String> get _categories =>
      _type == TxType.ingreso ? kIncomeCategories : kExpenseCategories;

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) return;
    setState(() => _saving = true);
    try {
      await ref.read(financeRepositoryProvider).addTransaction(Transaction(
            id: '',
            type: _type,
            category: _category,
            amount: amount,
            occurredOn: _date,
            description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          ));
      ref.invalidate(transactionsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Nuevo movimiento',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          SegmentedButton<TxType>(
            segments: const [
              ButtonSegment(value: TxType.gasto, label: Text('Gasto')),
              ButtonSegment(value: TxType.ingreso, label: Text('Ingreso')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              _category = _categories.first;
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Categoría'),
            items: [
              for (final c in _categories)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: 'Monto', prefixText: r'$ '),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            decoration:
                const InputDecoration(labelText: 'Descripción (opcional)'),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
                locale: const Locale('es', 'AR'),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Fecha'),
              child: Text(Fmt.date(_date)),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Proveedores
// =====================================================================
class _SuppliersTab extends ConsumerWidget {
  const _SuppliersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(suppliersProvider);
    return Scaffold(
      body: suppliersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _LockedNotice(error: e),
        data: (suppliers) {
          if (suppliers.isEmpty) {
            return const Center(child: Text('Sin proveedores cargados.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(suppliersProvider),
            child: ListView.builder(
              itemCount: suppliers.length,
              itemBuilder: (ctx, i) {
                final s = suppliers[i];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.store)),
                  title: Text(s.name),
                  subtitle: Text([
                    if (s.category != null) s.category!,
                    if (s.phone != null) s.phone!,
                  ].join(' · ')),
                  onTap: () => _showAddSupplier(context, ref, existing: s),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSupplier(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddSupplier(BuildContext context, WidgetRef ref,
      {Supplier? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final category = TextEditingController(text: existing?.category ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(existing == null ? 'Nuevo proveedor' : 'Editar proveedor',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nombre')),
            const SizedBox(height: 12),
            TextField(
                controller: category,
                decoration: const InputDecoration(
                    labelText: 'Rubro (comida, bebidas, ...)')),
            const SizedBox(height: 12),
            TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Teléfono')),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                await ref.read(financeRepositoryProvider).upsertSupplier(
                      Supplier(
                        id: existing?.id ?? '',
                        name: name.text.trim(),
                        category: category.text.trim().isEmpty
                            ? null
                            : category.text.trim(),
                        phone: phone.text.trim().isEmpty
                            ? null
                            : phone.text.trim(),
                      ),
                      id: existing?.id,
                    );
                ref.invalidate(suppliersProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedNotice extends StatelessWidget {
  const _LockedNotice({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 40, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('Solo los administradores pueden ver las finanzas.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
