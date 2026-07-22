import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../profiles/data/profile_repository.dart';
import '../../profiles/domain/profile.dart';
import '../application/events_providers.dart';
import '../data/event_repository.dart';
import '../domain/event.dart';
import '../domain/event_status.dart';

/// Alta y edición de un cumpleaños con todos sus datos.
class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({super.key, this.eventId, this.initialDate});

  final String? eventId;
  final DateTime? initialDate;

  bool get isEditing => eventId != null;

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _childName = TextEditingController();
  final _childAge = TextEditingController();
  final _kids = TextEditingController();
  final _adults = TextEditingController();
  final _clientName = TextEditingController();
  final _clientPhone = TextEditingController();
  final _food = TextEditingController();
  final _notes = TextEditingController();
  final _price = TextEditingController();
  final _deposit = TextEditingController();
  final _hours = TextEditingController();

  DateTime _date = DateTime.now();
  TimeOfDay? _start;
  TimeOfDay? _end;
  TimeOfDay? _drinks;
  EventStatus _status = EventStatus.presupuestado;
  String? _coordinatorId;
  final Set<String> _staffIds = {};

  // Pago a registrar junto con el evento (opcional).
  final _payAmount = TextEditingController();
  String _payKind = 'Seña'; // 'Seña' | 'Total'

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now();
    if (widget.isEditing) _loadExisting();
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    final e = await ref.read(eventRepositoryProvider).fetchById(widget.eventId!);
    if (e != null && mounted) {
      _childName.text = e.childName;
      _childAge.text = e.childAge?.toString() ?? '';
      _kids.text = e.kidsCount?.toString() ?? '';
      _adults.text = e.adultsCount?.toString() ?? '';
      _clientName.text = e.clientName ?? '';
      _clientPhone.text = e.clientPhone ?? '';
      _food.text = e.foodNotes ?? '';
      _notes.text = e.notes ?? '';
      _price.text = e.price == 0 ? '' : e.price.toStringAsFixed(0);
      _deposit.text = e.deposit == 0 ? '' : e.deposit.toStringAsFixed(0);
      _hours.text = e.laborHours == null
          ? ''
          : (e.laborHours! % 1 == 0
              ? e.laborHours!.toStringAsFixed(0)
              : e.laborHours!.toString());
      _date = e.eventDate;
      _start = e.startTime;
      _end = e.endTime;
      _drinks = e.drinksTime;
      _status = e.status;
      _coordinatorId = e.coordinatorId;
      _staffIds
        ..clear()
        ..addAll(e.staffIds);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [
      _childName, _childAge, _kids, _adults, _clientName,
      _clientPhone, _food, _notes, _price, _deposit, _payAmount, _hours,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _toInt(String s) => s.trim().isEmpty ? null : int.tryParse(s.trim());
  double _toDouble(String s) =>
      s.trim().isEmpty ? 0 : double.tryParse(s.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('es', 'AR'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay? initial) => showTimePicker(
        context: context,
        initialTime: initial ?? const TimeOfDay(hour: 16, minute: 0),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final event = Event(
      id: widget.eventId ?? '',
      childName: _childName.text.trim(),
      eventDate: _date,
      childAge: _toInt(_childAge.text),
      startTime: _start,
      endTime: _end,
      kidsCount: _toInt(_kids.text),
      adultsCount: _toInt(_adults.text),
      clientName: _clientName.text.trim().isEmpty ? null : _clientName.text.trim(),
      clientPhone:
          _clientPhone.text.trim().isEmpty ? null : _clientPhone.text.trim(),
      drinksTime: _drinks,
      foodNotes: _food.text.trim().isEmpty ? null : _food.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      price: _toDouble(_price.text),
      deposit: _toDouble(_deposit.text),
      status: _status,
      coordinatorId: _coordinatorId,
      laborHours: _toDouble(_hours.text) == 0 ? null : _toDouble(_hours.text),
      staffIds: _staffIds.toList(),
    );

    try {
      final repo = ref.read(eventRepositoryProvider);
      final String savedId;
      if (widget.isEditing) {
        await repo.update(event);
        savedId = widget.eventId!;
      } else {
        savedId = await repo.create(event);
      }
      // Registrar el pago cargado en el formulario (si hay).
      final payAmount = _toDouble(_payAmount.text);
      if (payAmount > 0) {
        await repo.addPayment(
          eventId: savedId,
          amount: payAmount,
          note: _payKind == 'Total' ? 'Pago total' : 'Seña',
        );
      }
      ref.invalidate(monthEventsProvider);
      ref.invalidate(eventDetailProvider(savedId));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(activeProfilesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar cumpleaños' : 'Nuevo cumpleaños'),
      ),
      body: _loading && widget.isEditing
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _section('Festejado', Icons.cake_rounded, AppColors.kids),
                  TextFormField(
                    controller: _childName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: 'Nombre del niño/a *'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _childAge,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Edad que cumple'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dateField(),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _timeField('Desde', _start,
                            (t) => setState(() => _start = t))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _timeField('Hasta', _end,
                            (t) => setState(() => _end = t))),
                  ]),

                  _section('Cantidades y contacto', Icons.groups_rounded, AppColors.info),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _kids,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Cant. niños'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _adults,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Cant. adultos'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _clientName,
                    textCapitalization: TextCapitalization.words,
                    decoration:
                        const InputDecoration(labelText: 'Cliente / responsable'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _clientPhone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'Teléfono', prefixIcon: Icon(Icons.phone)),
                  ),

                  _section('Logística', Icons.local_shipping_rounded, AppColors.expense),
                  _timeField('Hora en que llevan las bebidas', _drinks,
                      (t) => setState(() => _drinks = t)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _food,
                    decoration: const InputDecoration(
                        labelText: 'Qué comida llevan (si informan)'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notes,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: 'Observaciones'),
                  ),

                  _section('Dinero', Icons.attach_money_rounded, AppColors.income),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _price,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Precio', prefixText: r'$ '),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _deposit,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Seña', prefixText: r'$ '),
                      ),
                    ),
                  ]),

                  _section('Organización', Icons.groups_2_rounded, AppColors.brand),
                  DropdownButtonFormField<EventStatus>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: [
                      for (final s in _statusOptions)
                        DropdownMenuItem(value: s, child: Text(s.label)),
                    ],
                    onChanged: (v) => setState(() => _status = v ?? _status),
                  ),
                  const SizedBox(height: 12),
                  _paymentSection(),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _hours,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Horas de trabajo (opcional)',
                      helperText: 'Cuántas horas les demandó, para el \$/hora',
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  profilesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('No se pudo cargar el equipo: $e'),
                    data: (profiles) => _teamSelectors(profiles),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _loading ? null : _save,
                    icon: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check),
                    label: const Text('Guardar'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _teamSelectors(List<Profile> profiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String?>(
          initialValue: _coordinatorId,
          decoration:
              const InputDecoration(labelText: 'Coordinador asignado'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Sin asignar')),
            for (final p in profiles)
              DropdownMenuItem(value: p.id, child: Text(p.displayName)),
          ],
          onChanged: (v) => setState(() => _coordinatorId = v),
        ),
        const SizedBox(height: 16),
        Text('Trabajadores asignados',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in profiles)
              FilterChip(
                label: Text(p.displayName),
                selected: _staffIds.contains(p.id),
                onSelected: (sel) => setState(() {
                  if (sel) {
                    _staffIds.add(p.id);
                  } else {
                    _staffIds.remove(p.id);
                  }
                }),
              ),
          ],
        ),
      ],
    );
  }

  Widget _dateField() {
    return InkWell(
      onTap: _pickDate,
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Fecha *'),
        child: Text(Fmt.date(_date)),
      ),
    );
  }

  Widget _timeField(
      String label, TimeOfDay? value, ValueChanged<TimeOfDay?> onChanged) {
    return InkWell(
      onTap: () async {
        final picked = await _pickTime(value);
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value == null
              ? const Icon(Icons.schedule)
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => onChanged(null),
                ),
        ),
        child: Text(value == null ? '—' : Fmt.time(value)),
      ),
    );
  }

  /// Solo Presupuestado y Confirmado (más el estado actual si el evento ya
  /// tiene otro, para no romper la edición de eventos viejos).
  List<EventStatus> get _statusOptions {
    final opts = <EventStatus>{
      EventStatus.presupuestado,
      EventStatus.confirmado,
      _status,
    };
    return opts.toList();
  }

  Widget _paymentSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.income.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.payments_rounded, size: 18, color: AppColors.income),
              SizedBox(width: 8),
              Text('Agregar pago',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Seña', label: Text('Seña')),
              ButtonSegment(value: 'Total', label: Text('Total')),
            ],
            selected: {_payKind},
            onSelectionChanged: (s) => setState(() {
              _payKind = s.first;
              if (_payKind == 'Total') {
                final price = _toDouble(_price.text);
                if (price > 0) _payAmount.text = price.toStringAsFixed(0);
              }
            }),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _payAmount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Monto del pago (opcional)', prefixText: r'$ '),
          ),
          const SizedBox(height: 6),
          const Text(
            'Se registra al guardar y suma a lo cobrado del evento.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, IconData icon, Color color) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 10),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      );
}
