import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/inventory_item.dart';
import '../domain/maintenance_task.dart';

class MaintenanceRepository {
  MaintenanceRepository(this._client);
  final SupabaseClient _client;

  // -------- Mantenimiento --------

  Future<List<MaintenanceTask>> fetchTasks() async {
    final data = await _client
        .from('maintenance_tasks')
        .select()
        .order('status')
        .order('due_date', nullsFirst: false);
    return (data as List)
        .map((e) => MaintenanceTask.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsertTask(MaintenanceTask task, {String? id}) async {
    if (id == null) {
      await _client.from('maintenance_tasks').insert(task.toWriteMap());
    } else {
      await _client
          .from('maintenance_tasks')
          .update(task.toWriteMap())
          .eq('id', id);
    }
  }

  Future<void> setStatus(String id, MaintenanceStatus status) async {
    await _client.from('maintenance_tasks').update({
      'status': status.db,
      'resolved_at': status == MaintenanceStatus.resuelto
          ? DateTime.now().toIso8601String().split('T').first
          : null,
    }).eq('id', id);
  }

  Future<void> deleteTask(String id) async {
    await _client.from('maintenance_tasks').delete().eq('id', id);
  }

  // -------- Inventario --------

  Future<List<InventoryItem>> fetchInventory() async {
    final data =
        await _client.from('inventory_items').select().order('name');
    return (data as List)
        .map((e) => InventoryItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsertItem(InventoryItem item, {String? id}) async {
    if (id == null) {
      await _client.from('inventory_items').insert(item.toWriteMap());
    } else {
      await _client
          .from('inventory_items')
          .update(item.toWriteMap())
          .eq('id', id);
    }
  }

  Future<void> adjustQuantity(String id, double newQuantity) async {
    await _client
        .from('inventory_items')
        .update({'quantity': newQuantity}).eq('id', id);
  }

  Future<void> deleteItem(String id) async {
    await _client.from('inventory_items').delete().eq('id', id);
  }
}

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  return MaintenanceRepository(ref.watch(supabaseClientProvider));
});

final maintenanceTasksProvider =
    FutureProvider<List<MaintenanceTask>>((ref) async {
  return ref.watch(maintenanceRepositoryProvider).fetchTasks();
});

final inventoryProvider = FutureProvider<List<InventoryItem>>((ref) async {
  return ref.watch(maintenanceRepositoryProvider).fetchInventory();
});
