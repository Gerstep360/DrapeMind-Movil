import 'package:flutter/material.dart';

/// Tokens compartidos de DrapeMind Flow UI.
///
/// Mantiene medidas, radios, sombras y movimiento fuera de las pantallas para
/// que los casos de uso no creen un lenguaje visual paralelo.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class AppRadii {
  static const double small = 14;
  static const double medium = 20;
  static const double large = 28;
  static const double sheet = 32;
  static const double pill = 999;
}

abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 500);
  static const Curve expressive = Cubic(0.22, 1, 0.36, 1);
}

abstract final class AppShadows {
  static const List<BoxShadow> surface = [
    BoxShadow(color: Color(0x0F10110F), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x1F10110F), blurRadius: 34, offset: Offset(0, 14)),
  ];
}
