import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import 'event_status.dart';

/// Un cumpleaños con todos sus datos. Inmutable.
@immutable
class Event {
  const Event({
    required this.id,
    required this.childName,
    required this.eventDate,
    this.childAge,
    this.startTime,
    this.endTime,
    this.kidsCount,
    this.adultsCount,
    this.clientName,
    this.clientPhone,
    this.drinksTime,
    this.foodNotes,
    this.notes,
    this.price = 0,
    this.deposit = 0,
    this.status = EventStatus.presupuestado,
    this.coordinatorId,
    this.laborHours,
    this.totalPaid = 0,
    this.staffIds = const [],
  });

  final String id;
  final String childName;
  final DateTime eventDate;
  final int? childAge;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final int? kidsCount;
  final int? adultsCount;
  final String? clientName;
  final String? clientPhone;
  final TimeOfDay? drinksTime;
  final String? foodNotes;
  final String? notes;
  final double price;
  final double deposit;
  final EventStatus status;
  final String? coordinatorId;

  /// Horas de trabajo que demandó el cumpleaños (para calcular $/hora).
  final double? laborHours;

  /// Total ya cobrado (viene de la vista events_with_balance).
  final double totalPaid;

  /// Ids de trabajadores asignados (se completan aparte, desde event_staff).
  final List<String> staffIds;

  double get balanceDue => (price - totalPaid).clamp(0, double.infinity);
  bool get isPaid => balanceDue <= 0 && price > 0;

  String get timeRange {
    if (startTime == null) return 'Sin horario';
    final start = Fmt.time(startTime!);
    if (endTime == null) return start;
    return '$start – ${Fmt.time(endTime!)}';
  }

  factory Event.fromMap(Map<String, dynamic> map) {
    double num2(dynamic v) => (v as num?)?.toDouble() ?? 0;
    return Event(
      id: map['id'] as String,
      childName: (map['child_name'] as String?) ?? '',
      eventDate: DateTime.parse(map['event_date'] as String),
      childAge: (map['child_age'] as num?)?.toInt(),
      startTime: Fmt.parseTime(map['start_time'] as String?),
      endTime: Fmt.parseTime(map['end_time'] as String?),
      kidsCount: (map['kids_count'] as num?)?.toInt(),
      adultsCount: (map['adults_count'] as num?)?.toInt(),
      clientName: map['client_name'] as String?,
      clientPhone: map['client_phone'] as String?,
      drinksTime: Fmt.parseTime(map['drinks_time'] as String?),
      foodNotes: map['food_notes'] as String?,
      notes: map['notes'] as String?,
      price: num2(map['price']),
      deposit: num2(map['deposit']),
      status: EventStatus.fromDb(map['status'] as String?),
      coordinatorId: map['coordinator_id'] as String?,
      laborHours: (map['labor_hours'] as num?)?.toDouble(),
      totalPaid: num2(map['total_paid']),
    );
  }

  /// Para insert/update en la tabla events (sin campos calculados).
  Map<String, dynamic> toWriteMap() => {
        'child_name': childName,
        'event_date':
            '${eventDate.year.toString().padLeft(4, '0')}-${eventDate.month.toString().padLeft(2, '0')}-${eventDate.day.toString().padLeft(2, '0')}',
        'child_age': childAge,
        'start_time': Fmt.serializeTime(startTime),
        'end_time': Fmt.serializeTime(endTime),
        'kids_count': kidsCount,
        'adults_count': adultsCount,
        'client_name': clientName,
        'client_phone': clientPhone,
        'drinks_time': Fmt.serializeTime(drinksTime),
        'food_notes': foodNotes,
        'notes': notes,
        'price': price,
        'deposit': deposit,
        'status': status.db,
        'coordinator_id': coordinatorId,
        'labor_hours': laborHours,
      };

  Event copyWith({
    String? childName,
    DateTime? eventDate,
    int? childAge,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    int? kidsCount,
    int? adultsCount,
    String? clientName,
    String? clientPhone,
    TimeOfDay? drinksTime,
    String? foodNotes,
    String? notes,
    double? price,
    double? deposit,
    EventStatus? status,
    String? coordinatorId,
    double? laborHours,
    double? totalPaid,
    List<String>? staffIds,
  }) {
    return Event(
      id: id,
      childName: childName ?? this.childName,
      eventDate: eventDate ?? this.eventDate,
      childAge: childAge ?? this.childAge,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      kidsCount: kidsCount ?? this.kidsCount,
      adultsCount: adultsCount ?? this.adultsCount,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      drinksTime: drinksTime ?? this.drinksTime,
      foodNotes: foodNotes ?? this.foodNotes,
      notes: notes ?? this.notes,
      price: price ?? this.price,
      deposit: deposit ?? this.deposit,
      status: status ?? this.status,
      coordinatorId: coordinatorId ?? this.coordinatorId,
      laborHours: laborHours ?? this.laborHours,
      totalPaid: totalPaid ?? this.totalPaid,
      staffIds: staffIds ?? this.staffIds,
    );
  }
}
