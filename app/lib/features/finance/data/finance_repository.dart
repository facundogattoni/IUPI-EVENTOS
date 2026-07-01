import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/supplier.dart';
import '../domain/transaction.dart';

String _dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class FinanceRepository {
  FinanceRepository(this._client);
  final SupabaseClient _client;

  // -------- Transacciones --------

  Future<List<Transaction>> fetchInRange(DateTime from, DateTime to) async {
    final data = await _client
        .from('transactions')
        .select()
        .gte('occurred_on', _dateOnly(from))
        .lte('occurred_on', _dateOnly(to))
        .order('occurred_on', ascending: false);
    return (data as List)
        .map((e) => Transaction.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addTransaction(Transaction tx) async {
    await _client.from('transactions').insert(tx.toWriteMap());
  }

  Future<void> deleteTransaction(String id) async {
    await _client.from('transactions').delete().eq('id', id);
  }

  // -------- Proveedores --------

  Future<List<Supplier>> fetchSuppliers({bool onlyActive = true}) async {
    var query = _client.from('suppliers').select();
    if (onlyActive) query = query.eq('is_active', true);
    final data = await query.order('name');
    return (data as List)
        .map((e) => Supplier.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsertSupplier(Supplier s, {String? id}) async {
    if (id == null) {
      await _client.from('suppliers').insert(s.toWriteMap());
    } else {
      await _client.from('suppliers').update(s.toWriteMap()).eq('id', id);
    }
  }
}

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(ref.watch(supabaseClientProvider));
});
