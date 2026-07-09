import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/capital_asset.dart';
import '../domain/exchange_rate.dart';

String _dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class AccountingRepository {
  AccountingRepository(this._client);
  final SupabaseClient _client;

  // -------- Cotización del dólar --------

  Future<List<ExchangeRate>> fetchRates({int limit = 60}) async {
    final data = await _client
        .from('exchange_rates')
        .select()
        .order('rate_date', ascending: false)
        .limit(limit);
    return (data as List)
        .map((e) => ExchangeRate.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<ExchangeRate?> latestRate() async {
    final data = await _client
        .from('exchange_rates')
        .select()
        .order('rate_date', ascending: false)
        .limit(1)
        .maybeSingle();
    return data == null ? null : ExchangeRate.fromMap(data);
  }

  Future<void> upsertRate(DateTime date, double usdArs) async {
    await _client.from('exchange_rates').upsert(
      {'rate_date': _dateOnly(date), 'usd_ars': usdArs},
      onConflict: 'rate_date',
    );
  }

  // -------- Inversiones / bienes de capital --------

  Future<List<CapitalAsset>> fetchAssets() async {
    final data = await _client
        .from('capital_assets')
        .select()
        .order('purchase_date', ascending: false);
    return (data as List)
        .map((e) => CapitalAsset.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsertAsset(CapitalAsset asset, {String? id}) async {
    if (id == null) {
      await _client.from('capital_assets').insert(asset.toWriteMap());
    } else {
      await _client
          .from('capital_assets')
          .update(asset.toWriteMap())
          .eq('id', id);
    }
  }

  Future<void> deleteAsset(String id) async {
    await _client.from('capital_assets').delete().eq('id', id);
  }
}

final accountingRepositoryProvider = Provider<AccountingRepository>((ref) {
  return AccountingRepository(ref.watch(supabaseClientProvider));
});

/// Última cotización cargada (o null si no hay ninguna).
final latestRateProvider = FutureProvider<ExchangeRate?>((ref) async {
  ref.watch(sessionProvider);
  return ref.watch(accountingRepositoryProvider).latestRate();
});

final ratesProvider = FutureProvider<List<ExchangeRate>>((ref) async {
  return ref.watch(accountingRepositoryProvider).fetchRates();
});

final assetsProvider = FutureProvider<List<CapitalAsset>>((ref) async {
  return ref.watch(accountingRepositoryProvider).fetchAssets();
});
