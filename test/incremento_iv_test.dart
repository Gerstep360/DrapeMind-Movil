import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';
import 'package:drapemind_mobile/core/theme/app_theme.dart';
import 'package:drapemind_mobile/segundo_parcial/cu27_dashboard/cu27_dashboard_screen.dart';
import 'incremento_ii_offline_test.dart' show loadOfflineFonts;

class DashboardApi extends ApiClient {
  bool fail = false;
  int days = 0;
  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    days = queryParams!['days'];
    if (fail) {
      throw ApiException('La sesión de esta tienda venció', statusCode: 401);
    }
    return {
      'empresa': 'Moda Oriente',
      'sucursal': 'Todas las sucursales',
      'desde': '2026-11-01',
      'hasta': '2026-11-06',
      'ingreso_neto_cobrado': '200.00',
      'pedidos_pagados': 2,
      'inventario_actual': {
        'unidades_disponibles': 8,
        'variantes_con_stock_bajo': 1,
      },
      'prendas_vendidas': [],
      'alcance': 'Inventario actual; ingresos del periodo consultado.',
    };
  }
}

void main() {
  setUpAll(loadOfflineFonts);
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'Dashboard $width renders facts and exposes an authentication error',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final api = DashboardApi();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.luxuryTheme,
            home: BusinessDashboardScreen(api: api),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Bs 200.00'), findsOneWidget);
        expect(api.days, 30);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(BusinessDashboardScreen),
          matchesGoldenFile(
            '../qa/incremento-iv/dashboard-${width.toInt()}.png',
          ),
        );
        api.fail = true;
        await tester.drag(find.byType(ListView), const Offset(0, 500));
        await tester.pumpAndSettle();
        expect(find.text('La sesión de esta tienda venció'), findsOneWidget);
        expect(find.text('Bs 200.00'), findsNothing);
        expect(find.text('Reintentar'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
