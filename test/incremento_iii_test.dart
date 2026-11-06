import 'dart:typed_data';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';
import 'package:drapemind_mobile/core/theme/app_theme.dart';
import 'package:drapemind_mobile/incrementos/incremento_iii/checkout_confirmation.dart';
import 'package:drapemind_mobile/incrementos/incremento_iii/native_actions.dart';
import 'package:drapemind_mobile/incrementos/incremento_iii/reports_screen.dart';
import 'incremento_ii_offline_test.dart' show loadOfflineFonts;
import 'dart:io';

final report = {
  'id': 1,
  'titulo': 'Balance de la tienda',
  'consulta': 'Ventas de hoy',
  'analisis': 'Los datos muestran cobros confirmados e inventario disponible.',
  'recomendaciones': ['Revisar la disponibilidad de tallas.'],
  'datos': {
    'empresa': 'Moda Oriente',
    'desde': '2026-11-04',
    'hasta': '2026-11-04',
    'sucursal': 'Todas las sucursales',
    'pedidos_pagados': 2,
    'ingreso_neto_cobrado': '200.00',
    'inventario_actual': {
      'unidades_disponibles': 8,
      'variantes_con_stock_bajo': 0,
    },
    'alcance':
        'Los ingresos excluyen los créditos de cambio. El inventario es actual.',
  },
};

class IIIApi extends ApiClient {
  bool drop = true;
  int posts = 0;
  Map<String, dynamic>? saved;
  Map<String, dynamic>? reportInput;
  @override
  Future<String?> getToken() async =>
      'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': '4', 'tid': 1})))}.signature';
  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (path == '/business-reports') return [];
    if (path.startsWith('/orders/checkout-operations/')) {
      if (saved != null) return {'id': 27};
      throw NotFoundException('No existe', statusCode: 404);
    }
    return {};
  }

  @override
  Future<dynamic> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    if (path == '/business-reports') {
      reportInput = Map<String, dynamic>.from(body);
      return report;
    }
    posts++;
    saved = Map<String, dynamic>.from(body);
    if (drop) {
      drop = false;
      throw NetworkException('Respuesta perdida');
    }
    return {'id': 27};
  }

  @override
  Future<Uint8List> getBytes(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) async => Uint8List.fromList(utf8.encode('%PDF-1.4'));
}

class IIIActions extends NativeActions {
  String? filename;
  @override
  Future<String?> dictate() async => 'Revisa las ventas de hoy';
  @override
  Future<bool> savePdf(String name, Uint8List bytes) async {
    filename = name;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadOfflineFonts);
  test(
    'checkout survives a lost response and recovers the same UUID',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = IIIApi();
      final body = {'tipo_entrega': 'RECOJO', 'sucursal_id': 1};
      await expectLater(
        CheckoutConfirmation(api).confirm(body),
        throwsA(isA<NetworkException>()),
      );
      final uuid = api.saved!['operacion_id'];
      expect(uuid, hasLength(36));
      final order = await CheckoutConfirmation(api).confirm(body);
      expect(order['id'], 27);
      expect(api.posts, 1);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    },
  );
  for (final width in [320.0, 390.0]) {
    testWidgets('reports text and voice workflow at $width pixels', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = IIIApi(), actions = IIIActions();
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.luxuryTheme,
          home: RepaintBoundary(
            key: key,
            child: ReportsScreen(api: api, actions: actions),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dictar consulta'));
      await tester.pumpAndSettle();
      expect(find.text('Revisa las ventas de hoy'), findsOneWidget);
      await tester.tap(find.text('Generar reporte'));
      await tester.pumpAndSettle();
      expect(api.reportInput!['entrada'], 'VOZ');
      await tester.scrollUntilVisible(
        find.text('Descargar PDF'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Descargar PDF'));
      await tester.pumpAndSettle();
      expect(actions.filename, 'reporte-1.pdf');
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final img = await boundary.toImage(pixelRatio: 1);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        final output = File('qa/incremento-iii/report-${width.toInt()}.png');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes!.buffer.asUint8List());
        img.dispose();
      });
    });
  }
}
