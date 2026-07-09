import 'package:flutter/material.dart';

/// Paleta de la app: oscura, con acentos y colores semánticos (estilo panel
/// de gestión). Un solo lugar para todos los colores de marca.
class AppColors {
  const AppColors._();

  // Marca
  static const Color brand = Color(0xFF7C5CFF); // violeta IUPI
  static const Color gold = Color(0xFFE0B341); // dorado de acento

  // Fondos (modo oscuro)
  static const Color bg = Color(0xFF0E1116); // fondo general
  static const Color surface = Color(0xFF161B22); // tarjetas
  static const Color surfaceAlt = Color(0xFF1C222B); // tarjetas/hover
  static const Color border = Color(0xFF262D38);
  static const Color sidebar = Color(0xFF10141A);

  // Semánticos
  static const Color income = Color(0xFF22C55E); // ingresos / positivo
  static const Color expense = Color(0xFFF59E0B); // gastos
  static const Color danger = Color(0xFFEF4444); // alertas / saldos
  static const Color info = Color(0xFF38BDF8); // datos / neutro
  static const Color kids = Color(0xFFEC4899); // cumpleaños / festejado

  // Texto
  static const Color textStrong = Color(0xFFF3F5F8);
  static const Color textMuted = Color(0xFF9AA6B2);
}
