import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/events/domain/event.dart';
import 'formatters.dart';

/// Utilidades para comunicarse con el cliente: WhatsApp y llamada telefónica.
///
/// Ahorra tiempo y reduce errores: en vez de copiar datos a mano en WhatsApp,
/// se abre el chat con un mensaje ya redactado a partir del evento.
class Messaging {
  const Messaging._();

  /// Normaliza un teléfono argentino al formato que espera wa.me (solo dígitos,
  /// con código de país). Best-effort: quita espacios, 0 inicial y el 15 local,
  /// y antepone 54 9 (celular AR) si no viene con código de país.
  static String? normalizePhoneAr(String? raw) {
    if (raw == null) return null;
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;

    // Ya trae código de país argentino.
    if (digits.startsWith('54')) return digits;

    // Quitar 0 de larga distancia inicial (ej: 0264...).
    if (digits.startsWith('0')) digits = digits.substring(1);

    // Quitar el 15 de celular si quedó al principio (poco común ya sin el 0).
    if (digits.startsWith('15')) digits = digits.substring(2);

    // Celular argentino: 54 + 9 + área + número.
    return '549$digits';
  }

  /// Mensaje de confirmación del cumpleaños.
  static String confirmationMessage(Event e) {
    final hola = _greeting(e.clientName);
    final horario = e.startTime == null ? '' : ' de ${e.timeRange}';
    return '$hola Te confirmamos el cumple de ${e.childName} '
        'el ${Fmt.date(e.eventDate)}$horario en IUPI. 🎉\n'
        'Cualquier cosa, escribinos. ¡Gracias!';
  }

  /// Recordatorio de saldo pendiente.
  static String balanceReminderMessage(Event e) {
    final hola = _greeting(e.clientName);
    return '$hola Te recordamos que queda un saldo de ${Fmt.money(e.balanceDue)} '
        'para el cumple de ${e.childName} del ${Fmt.date(e.eventDate)}. '
        '¡Gracias!';
  }

  static String _greeting(String? clientName) {
    final name = (clientName ?? '').trim();
    return name.isEmpty ? '¡Hola!' : '¡Hola $name!';
  }

  /// Abre WhatsApp con el mensaje pre-cargado. Devuelve false si no se pudo.
  static Future<bool> openWhatsApp({
    required String? phone,
    required String message,
  }) async {
    final normalized = normalizePhoneAr(phone);
    if (normalized == null) return false;
    final uri = Uri.parse(
        'https://wa.me/$normalized?text=${Uri.encodeComponent(message)}');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Inicia una llamada telefónica. Devuelve false si no se pudo.
  static Future<bool> call(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return false;
    final uri = Uri(scheme: 'tel', path: phone.trim());
    return launchUrl(uri);
  }
}

/// Muestra un menú para elegir qué mensaje de WhatsApp enviar al cliente.
Future<void> showWhatsAppMenu(BuildContext context, Event event) async {
  if (Messaging.normalizePhoneAr(event.clientPhone) == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('El evento no tiene teléfono del cliente.')),
    );
    return;
  }

  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Enviar por WhatsApp',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          ListTile(
            leading: const Icon(Icons.celebration_outlined),
            title: const Text('Confirmación del cumple'),
            onTap: () => Navigator.pop(ctx, 'confirm'),
          ),
          if (event.balanceDue > 0)
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('Recordatorio de saldo'),
              subtitle: Text('Faltan ${Fmt.money(event.balanceDue)}'),
              onTap: () => Navigator.pop(ctx, 'balance'),
            ),
        ],
      ),
    ),
  );

  if (choice == null) return;
  final message = choice == 'balance'
      ? Messaging.balanceReminderMessage(event)
      : Messaging.confirmationMessage(event);
  final ok = await Messaging.openWhatsApp(
      phone: event.clientPhone, message: message);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
    );
  }
}
