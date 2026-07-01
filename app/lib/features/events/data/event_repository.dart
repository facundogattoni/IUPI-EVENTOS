import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/event.dart';
import '../domain/payment.dart';

String _dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class EventRepository {
  EventRepository(this._client);
  final SupabaseClient _client;

  /// Eventos entre dos fechas (inclusive), leídos de la vista con saldo.
  Future<List<Event>> fetchInRange(DateTime from, DateTime to) async {
    final data = await _client
        .from('events_with_balance')
        .select()
        .gte('event_date', _dateOnly(from))
        .lte('event_date', _dateOnly(to))
        .order('event_date')
        .order('start_time', nullsFirst: false);
    return (data as List)
        .map((e) => Event.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<Event?> fetchById(String id) async {
    final data = await _client
        .from('events_with_balance')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    final event = Event.fromMap(data);
    final staff = await fetchStaffIds(id);
    return event.copyWith(staffIds: staff);
  }

  /// Crea el evento y devuelve su id.
  Future<String> create(Event event) async {
    final inserted = await _client
        .from('events')
        .insert(event.toWriteMap())
        .select('id')
        .single();
    final id = inserted['id'] as String;
    await setStaff(id, event.staffIds);
    return id;
  }

  Future<void> update(Event event) async {
    await _client.from('events').update(event.toWriteMap()).eq('id', event.id);
    await setStaff(event.id, event.staffIds);
  }

  Future<void> delete(String id) async {
    await _client.from('events').delete().eq('id', id);
  }

  // -------- Trabajadores asignados --------

  Future<List<String>> fetchStaffIds(String eventId) async {
    final data = await _client
        .from('event_staff')
        .select('profile_id')
        .eq('event_id', eventId);
    return (data as List).map((e) => e['profile_id'] as String).toList();
  }

  /// Reemplaza el set de trabajadores asignados por el indicado.
  Future<void> setStaff(String eventId, List<String> profileIds) async {
    await _client.from('event_staff').delete().eq('event_id', eventId);
    if (profileIds.isEmpty) return;
    await _client.from('event_staff').insert([
      for (final pid in profileIds) {'event_id': eventId, 'profile_id': pid},
    ]);
  }

  // -------- Pagos --------

  Future<List<Payment>> fetchPayments(String eventId) async {
    final data = await _client
        .from('event_payments')
        .select()
        .eq('event_id', eventId)
        .order('paid_at', ascending: false);
    return (data as List)
        .map((e) => Payment.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addPayment({
    required String eventId,
    required double amount,
    DateTime? paidAt,
    String? method,
    String? note,
  }) async {
    await _client.from('event_payments').insert({
      'event_id': eventId,
      'amount': amount,
      'paid_at': _dateOnly(paidAt ?? DateTime.now()),
      'method': method,
      'note': note,
    });
  }
}

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(ref.watch(supabaseClientProvider));
});
