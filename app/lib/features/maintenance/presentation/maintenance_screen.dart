import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../data/maintenance_repository.dart';
import '../domain/inventory_item.dart';
import '../domain/maintenance_task.dart';

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mantenimiento'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Tareas'),
            Tab(text: 'Inventario'),
          ]),
        ),
        body: const TabBarView(children: [
          _TasksTab(),
          _InventoryTab(),
        ]),
      ),
    );
  }
}

// =====================================================================
// Tareas de mantenimiento
// =====================================================================
class _TasksTab extends ConsumerWidget {
  const _TasksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(maintenanceTasksProvider);
    return Scaffold(
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(child: Text('Sin tareas de mantenimiento.'));
          }
          final pending = tasks.where((t) => !t.isDone).toList();
          final done = tasks.where((t) => t.isDone).toList();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(maintenanceTasksProvider),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final t in pending) _TaskTile(task: t, ref: ref),
                if (done.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text('Resueltas',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                for (final t in done) _TaskTile(task: t, ref: ref),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditTask(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.ref});
  final MaintenanceTask task;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red.withOpacity(0.15),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      confirmDismiss: (_) async {
        await ref.read(maintenanceRepositoryProvider).deleteTask(task.id);
        ref.invalidate(maintenanceTasksProvider);
        return true;
      },
      child: ListTile(
        onTap: () => _showEditTask(context, ref, existing: task),
        leading: Checkbox(
          value: task.isDone,
          onChanged: (v) async {
            await ref.read(maintenanceRepositoryProvider).setStatus(
                  task.id,
                  (v ?? false)
                      ? MaintenanceStatus.resuelto
                      : MaintenanceStatus.pendiente,
                );
            ref.invalidate(maintenanceTasksProvider);
          },
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isDone ? TextDecoration.lineThrough : null,
            color: task.isDone ? scheme.onSurfaceVariant : null,
          ),
        ),
        subtitle: Row(
          children: [
            if (task.category != null) ...[
              Text(task.category!,
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant)),
              const SizedBox(width: 8),
            ],
            if (task.dueDate != null)
              Text(
                Fmt.date(task.dueDate!),
                style: TextStyle(
                  fontSize: 12,
                  color: task.isOverdue ? scheme.error : scheme.onSurfaceVariant,
                  fontWeight:
                      task.isOverdue ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            if (task.recurDays != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.repeat, size: 12, color: scheme.onSurfaceVariant),
            ],
          ],
        ),
        trailing: Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: task.priority.color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

Future<void> _showEditTask(BuildContext context, WidgetRef ref,
    {MaintenanceTask? existing}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TaskSheet(existing: existing),
  );
}

class _TaskSheet extends ConsumerStatefulWidget {
  const _TaskSheet({this.existing});
  final MaintenanceTask? existing;

  @override
  ConsumerState<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends ConsumerState<_TaskSheet> {
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late final TextEditingController _recur;
  String? _category;
  MaintenancePriority _priority = MaintenancePriority.media;
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _desc = TextEditingController(text: e?.description ?? '');
    _recur = TextEditingController(text: e?.recurDays?.toString() ?? '');
    _category = e?.category;
    _priority = e?.priority ?? MaintenancePriority.media;
    _dueDate = e?.dueDate;
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _recur.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final task = MaintenanceTask(
      id: widget.existing?.id ?? '',
      title: _title.text.trim(),
      category: _category,
      description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      status: widget.existing?.status ?? MaintenanceStatus.pendiente,
      priority: _priority,
      dueDate: _dueDate,
      recurDays: int.tryParse(_recur.text.trim()),
    );
    try {
      await ref
          .read(maintenanceRepositoryProvider)
          .upsertTask(task, id: widget.existing?.id);
      ref.invalidate(maintenanceTasksProvider);
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'Nueva tarea' : 'Editar tarea',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
                controller: _title,
                decoration: const InputDecoration(
                    labelText: 'Tarea (ej: Reparar inflable)')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: [
                for (final c in kMaintenanceCategories)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Prioridad:'),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<MaintenancePriority>(
                    segments: const [
                      ButtonSegment(
                          value: MaintenancePriority.baja, label: Text('Baja')),
                      ButtonSegment(
                          value: MaintenancePriority.media, label: Text('Media')),
                      ButtonSegment(
                          value: MaintenancePriority.alta, label: Text('Alta')),
                    ],
                    selected: {_priority},
                    onSelectionChanged: (s) =>
                        setState(() => _priority = s.first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dueDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                  locale: const Locale('es', 'AR'),
                );
                if (picked != null) setState(() => _dueDate = picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Vencimiento / recordatorio',
                  suffixIcon: _dueDate == null
                      ? const Icon(Icons.event)
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _dueDate = null),
                        ),
                ),
                child: Text(_dueDate == null ? '—' : Fmt.date(_dueDate!)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _recur,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Repetir cada N días (opcional)',
                helperText: 'Ej: 365 para matafuegos, 180 para el aire',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
                controller: _desc,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Detalle')),
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
      ),
    );
  }
}

// =====================================================================
// Inventario
// =====================================================================
class _InventoryTab extends ConsumerWidget {
  const _InventoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invAsync = ref.watch(inventoryProvider);
    return Scaffold(
      body: invAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Sin insumos cargados.'));
          }
          final low = items.where((i) => i.isLow).length;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(inventoryProvider),
            child: ListView(
              children: [
                if (low > 0)
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      const Icon(Icons.warning_amber, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text('$low insumo(s) por debajo del mínimo'),
                    ]),
                  ),
                for (final item in items) _ItemTile(item: item, ref: ref),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditItem(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.ref});
  final InventoryItem item;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => _showEditItem(context, ref, existing: item),
      leading: CircleAvatar(
        backgroundColor: item.isLow
            ? Colors.orange.withOpacity(0.2)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          item.isLow ? Icons.warning_amber : Icons.inventory_2_outlined,
          color: item.isLow ? Colors.orange : null,
          size: 20,
        ),
      ),
      title: Text(item.name),
      subtitle: Text(item.category ?? ''),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () async {
              final q = (item.quantity - 1).clamp(0, double.infinity);
              await ref
                  .read(maintenanceRepositoryProvider)
                  .adjustQuantity(item.id, q.toDouble());
              ref.invalidate(inventoryProvider);
            },
          ),
          Text(item.quantityLabel,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () async {
              await ref
                  .read(maintenanceRepositoryProvider)
                  .adjustQuantity(item.id, item.quantity + 1);
              ref.invalidate(inventoryProvider);
            },
          ),
        ],
      ),
    );
  }
}

Future<void> _showEditItem(BuildContext context, WidgetRef ref,
    {InventoryItem? existing}) async {
  final name = TextEditingController(text: existing?.name ?? '');
  final category = TextEditingController(text: existing?.category ?? '');
  final quantity =
      TextEditingController(text: existing?.quantity.toStringAsFixed(0) ?? '0');
  final minQ = TextEditingController(
      text: existing?.minQuantity.toStringAsFixed(0) ?? '0');
  final unit = TextEditingController(text: existing?.unit ?? '');

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
            Text(existing == null ? 'Nuevo insumo' : 'Editar insumo',
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
                    labelText: 'Categoría (vajilla, limpieza, ...)')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                    controller: quantity,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cantidad')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                    controller: minQ,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Mínimo')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                    controller: unit,
                    decoration: const InputDecoration(labelText: 'Unidad')),
              ),
            ]),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                await ref.read(maintenanceRepositoryProvider).upsertItem(
                      InventoryItem(
                        id: existing?.id ?? '',
                        name: name.text.trim(),
                        category: category.text.trim().isEmpty
                            ? null
                            : category.text.trim(),
                        quantity:
                            double.tryParse(quantity.text.replaceAll(',', '.')) ??
                                0,
                        minQuantity:
                            double.tryParse(minQ.text.replaceAll(',', '.')) ?? 0,
                        unit: unit.text.trim().isEmpty ? null : unit.text.trim(),
                      ),
                      id: existing?.id,
                    );
                ref.invalidate(inventoryProvider);
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
