import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/messaging.dart';
import '../../profiles/data/profile_repository.dart';
import '../application/events_providers.dart';
import '../data/event_repository.dart';
import '../domain/event.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailProvider(eventId));
    final profilesAsync = ref.watch(activeProfilesProvider);
    final isAdmin =
        ref.watch(currentProfileProvider).valueOrNull?.role.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cumpleaños'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await context.push('/events/$eventId/edit');
              ref.invalidate(eventDetailProvider(eventId));
            },
          ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref),
            ),
        ],
      ),
      body: eventAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (event) {
          if (event == null) {
            return const Center(child: Text('El evento ya no existe.'));
          }
          final profiles = profilesAsync.valueOrNull ?? [];
          String nameOf(String? id) {
            for (final p in profiles) {
              if (p.id == id) return p.displayName;
            }
            return '—';
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(event: event),
              if (event.clientPhone != null &&
                  event.clientPhone!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _ContactActions(event: event),
              ],
              const SizedBox(height: 16),
              _MoneyCard(event: event, isAdmin: isAdmin, ref: ref),
              const SizedBox(height: 12),
              _InfoCard(title: 'Datos', rows: [
                _Row('Fecha', Fmt.date(event.eventDate)),
                _Row('Horario', event.timeRange),
                if (event.kidsCount != null)
                  _Row('Niños', '${event.kidsCount}'),
                if (event.adultsCount != null)
                  _Row('Adultos', '${event.adultsCount}'),
                if (event.clientName != null)
                  _Row('Cliente', event.clientName!),
                if (event.clientPhone != null)
                  _Row('Teléfono', event.clientPhone!),
              ]),
              const SizedBox(height: 12),
              _InfoCard(title: 'Logística', rows: [
                if (event.drinksTime != null)
                  _Row('Bebidas', Fmt.time(event.drinksTime!)),
                if (event.foodNotes != null) _Row('Comida', event.foodNotes!),
                if (event.notes != null) _Row('Observaciones', event.notes!),
                if (event.drinksTime == null &&
                    event.foodNotes == null &&
                    event.notes == null)
                  const _Row('—', 'Sin datos de logística'),
              ]),
              const SizedBox(height: 12),
              _InfoCard(title: 'Equipo', rows: [
                _Row('Coordinador', nameOf(event.coordinatorId)),
                _Row(
                  'Trabajadores',
                  event.staffIds.isEmpty
                      ? '—'
                      : event.staffIds.map(nameOf).join(', '),
                ),
              ]),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cumpleaños'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(eventRepositoryProvider).delete(eventId);
      ref.invalidate(monthEventsProvider);
      if (context.mounted) context.pop();
    }
  }
}

/// Botones rápidos para contactar al cliente por WhatsApp o teléfono.
class _ContactActions extends StatelessWidget {
  const _ContactActions({required this.event});
  final Event event;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () => showWhatsAppMenu(context, event),
            icon: const Icon(Icons.chat),
            label: const Text('WhatsApp'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final ok = await Messaging.call(event.clientPhone);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No se pudo iniciar la llamada.')),
                );
              }
            },
            icon: const Icon(Icons.call),
            label: const Text('Llamar'),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.event});
  final Event event;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.childAge != null
                    ? '${event.childName} · ${event.childAge} años'
                    : event.childName,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(Fmt.dayMonth(event.eventDate),
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: event.status.color(scheme).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(event.status.label,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: event.status.color(scheme))),
        ),
      ],
    );
  }
}

class _MoneyCard extends StatelessWidget {
  const _MoneyCard(
      {required this.event, required this.isAdmin, required this.ref});
  final Event event;
  final bool isAdmin;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer.withOpacity(0.4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _money(context, 'Precio', event.price),
                _money(context, 'Pagado', event.totalPaid),
                _money(context, 'Saldo', event.balanceDue,
                    highlight: event.balanceDue > 0),
              ],
            ),
            if (isAdmin) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showPayments(context),
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('Pagos'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _addPayment(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Registrar pago'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _money(BuildContext context, String label, double value,
      {bool highlight = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(Fmt.money(value),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: highlight ? scheme.error : scheme.onSurface)),
        ],
      ),
    );
  }

  Future<void> _addPayment(BuildContext context) async {
    final ctrl = TextEditingController(
        text: event.balanceDue > 0 ? event.balanceDue.toStringAsFixed(0) : '');
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar pago'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Monto', prefixText: r'$ '),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
              Navigator.pop(ctx, v);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (amount != null && amount > 0) {
      await ref
          .read(eventRepositoryProvider)
          .addPayment(eventId: event.id, amount: amount);
      ref.invalidate(eventDetailProvider(event.id));
      ref.invalidate(eventPaymentsProvider(event.id));
      ref.invalidate(monthEventsProvider);
    }
  }

  Future<void> _showPayments(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Consumer(
        builder: (ctx, r, _) {
          final payments = r.watch(eventPaymentsProvider(event.id));
          return payments.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Padding(
                padding: const EdgeInsets.all(24), child: Text('Error: $e')),
            data: (list) => ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Pagos registrados',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (list.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Todavía no hay pagos.')),
                for (final p in list)
                  ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: Text(Fmt.money(p.amount)),
                    subtitle: Text(
                        '${Fmt.date(p.paidAt)}${p.method != null ? ' · ${p.method}' : ''}'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});
  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 8),
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
