import 'package:flutter/material.dart';

enum MaintenanceStatus {
  pendiente('pendiente'),
  enProgreso('en_progreso'),
  resuelto('resuelto');

  const MaintenanceStatus(this.db);

  /// Valor exacto que se guarda en la base (enum maintenance_status).
  final String db;

  static MaintenanceStatus fromDb(String? v) => MaintenanceStatus.values
      .firstWhere((e) => e.db == v, orElse: () => MaintenanceStatus.pendiente);

  String get label {
    switch (this) {
      case MaintenanceStatus.pendiente:
        return 'Pendiente';
      case MaintenanceStatus.enProgreso:
        return 'En progreso';
      case MaintenanceStatus.resuelto:
        return 'Resuelto';
    }
  }
}

enum MaintenancePriority {
  baja,
  media,
  alta;

  static MaintenancePriority fromDb(String? v) => MaintenancePriority.values
      .firstWhere((e) => e.name == v, orElse: () => MaintenancePriority.media);
  String get db => name;
  String get label {
    switch (this) {
      case MaintenancePriority.baja:
        return 'Baja';
      case MaintenancePriority.media:
        return 'Media';
      case MaintenancePriority.alta:
        return 'Alta';
    }
  }

  Color get color {
    switch (this) {
      case MaintenancePriority.baja:
        return Colors.green;
      case MaintenancePriority.media:
        return Colors.orange;
      case MaintenancePriority.alta:
        return Colors.red;
    }
  }
}

/// Categorías típicas de mantenimiento del salón.
const kMaintenanceCategories = <String>[
  'inflable',
  'horno',
  'matafuegos',
  'aire',
  'electricidad',
  'plomería',
  'roturas',
  'limpieza',
  'vajilla',
  'otro',
];

@immutable
class MaintenanceTask {
  const MaintenanceTask({
    required this.id,
    required this.title,
    this.category,
    this.description,
    this.status = MaintenanceStatus.pendiente,
    this.priority = MaintenancePriority.media,
    this.dueDate,
    this.cost,
    this.recurDays,
    this.assignedTo,
    this.resolvedAt,
  });

  final String id;
  final String title;
  final String? category;
  final String? description;
  final MaintenanceStatus status;
  final MaintenancePriority priority;
  final DateTime? dueDate;
  final double? cost;
  final int? recurDays;
  final String? assignedTo;
  final DateTime? resolvedAt;

  bool get isDone => status == MaintenanceStatus.resuelto;

  bool get isOverdue =>
      !isDone &&
      dueDate != null &&
      dueDate!.isBefore(DateTime.now().subtract(const Duration(days: 0)));

  factory MaintenanceTask.fromMap(Map<String, dynamic> map) => MaintenanceTask(
        id: map['id'] as String,
        title: (map['title'] as String?) ?? '',
        category: map['category'] as String?,
        description: map['description'] as String?,
        status: MaintenanceStatus.fromDb(map['status'] as String?),
        priority: MaintenancePriority.fromDb(map['priority'] as String?),
        dueDate: map['due_date'] == null
            ? null
            : DateTime.parse(map['due_date'] as String),
        cost: (map['cost'] as num?)?.toDouble(),
        recurDays: (map['recur_days'] as num?)?.toInt(),
        assignedTo: map['assigned_to'] as String?,
        resolvedAt: map['resolved_at'] == null
            ? null
            : DateTime.parse(map['resolved_at'] as String),
      );

  Map<String, dynamic> toWriteMap() => {
        'title': title,
        'category': category,
        'description': description,
        'status': status.db,
        'priority': priority.db,
        'due_date': dueDate == null
            ? null
            : '${dueDate!.year.toString().padLeft(4, '0')}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}',
        'cost': cost,
        'recur_days': recurDays,
        'assigned_to': assignedTo,
      };
}
