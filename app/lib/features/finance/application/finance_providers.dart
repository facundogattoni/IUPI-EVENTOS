import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/finance_repository.dart';
import '../domain/supplier.dart';
import '../domain/transaction.dart';

/// Mes visible en la pantalla de movimientos (día 1).
final financeMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

final transactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  final month = ref.watch(financeMonthProvider);
  final from = DateTime(month.year, month.month, 1);
  final to = DateTime(month.year, month.month + 1, 0);
  return ref.watch(financeRepositoryProvider).fetchInRange(from, to);
});

final suppliersProvider = FutureProvider<List<Supplier>>((ref) async {
  return ref.watch(financeRepositoryProvider).fetchSuppliers();
});
