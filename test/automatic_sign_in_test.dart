import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/core/services/company_service.dart';
import 'package:drapemind_mobile/core/theme/app_theme.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/datos/servicios/auth_service.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/datos/servicios/security_service.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/iniciar_sesion/presentacion/login_screen.dart';
import 'package:drapemind_mobile/paquetes/saas/platform_screen.dart';
import 'support/golden_assets.dart';

String jwt(bool platform) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': '42', 'tid': platform ? null : 2, 'platform': platform, 'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000})))}.signature';
Map<String, dynamic> profile(bool platform) => {
  'id': 42,
  'tenant_id': platform ? null : 2,
  'is_platform_admin': platform,
  'tenant_slug': platform ? null : 'store-b',
  'tenant_name': platform ? null : 'Tienda B',
  'nombre': 'Cuenta de prueba',
  'email': 'account@example.com',
  'rol': platform ? 'ADMIN' : 'CLIENTE',
  'estado': 'ACTIVO',
  'created_at': '2026-01-01T00:00:00Z',
  'has_style_profile': true,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadGoldenFonts);
  final secure = <String, dynamic>{};
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  setUp(() {
    SharedPreferences.setMockInitialValues({'drapemind_company': 'old-store'});
    CompanyService.entrySlug = null;
    secure.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = Map<String, dynamic>.from(call.arguments ?? {});
          switch (call.method) {
            case 'read':
              return secure[args['key']];
            case 'write':
              secure[args['key']] = args['value'];
              return null;
            case 'delete':
              secure.remove(args['key']);
              return null;
            case 'deleteAll':
              secure.clear();
              return null;
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  for (final platform in [false, true]) {
    test(
      'identifies ${platform ? 'SaaS administration' : 'customer company'} in one request',
      () async {
        var calls = 0;
        final token = jwt(platform);
        final api = ApiClient(
          httpClient: MockClient((request) async {
            calls++;
            expect(request.url.path.endsWith('/auth/login'), true);
            expect(request.headers.containsKey('X-Tenant'), false);
            expect(request.headers.containsKey('Authorization'), false);
            expect(jsonDecode(request.body), {
              'email': 'account@example.com',
              'password': 'Password123!',
            });
            return http.Response(
              jsonEncode({
                'access_token': token,
                'expires_in': 3600,
                'token_type': 'bearer',
                'user': profile(platform),
                'tenant': platform
                    ? null
                    : {'id': 2, 'slug': 'store-b', 'name': 'Tienda B'},
                'redirect_path': platform ? '/saas-platform' : '/catalog',
              }),
              200,
            );
          }),
        );
        final auth = AuthService(apiClient: api);
        addTearDown(auth.dispose);
        final user = await auth.login('ACCOUNT@example.com', 'Password123!');
        expect(calls, 1);
        expect(user.isPlatformAdmin, platform);
        expect(auth.isPlatformAdmin, platform);
        expect(auth.destination, platform ? '/saas-platform' : '/catalog');
        expect(
          (await SharedPreferences.getInstance()).getString(CompanyService.key),
          platform ? null : 'store-b',
        );
        expect(secure['drapemind_auth_token'], token);
      },
    );
  }
  test(
    'store links supply context without asking the user for an identifier',
    () async {
      expect(
        await CompanyService.acceptStoreLink('drapemind://tienda/moda-oriente'),
        true,
      );
      expect(CompanyService.entrySlug, 'moda-oriente');
      expect(
        CompanyService.slugFromLink(
          'https://167.86.106.105/DrapeMind/tienda/urban-fit',
        ),
        'urban-fit',
      );
      expect(
        CompanyService.slugFromLink('drapemind://tienda/INVALID%20STORE'),
        null,
      );
    },
  );
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'login at $width has no company/role picker or demo credentials',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = AuthService();
        final security = SecurityService();
        addTearDown(auth.dispose);
        addTearDown(security.dispose);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: auth),
              ChangeNotifierProvider.value(value: security),
            ],
            child: MaterialApp(
              theme: AppTheme.luxuryTheme,
              home: RepaintBoundary(key: boundary, child: const LoginScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(Checkbox), findsNothing);
        expect(find.text('Empresa'), findsNothing);
        expect(find.text('ACCESOS RÁPIDOS DE PRUEBA'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = File(
            '.dart_tool/ui-review/login-${width.toInt()}.png',
          );
          await output.parent.create(recursive: true);
          await output.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      },
    );
  }
  testWidgets(
    'platform account sees companies without a company subscription gate',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.luxuryTheme,
          home: PlatformScreen(apiClient: PlatformApi()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Moda Oriente'), findsOneWidget);
      expect(find.text('Tus empresas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class PlatformApi extends ApiClient {
  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (path != '/saas/tenants') throw StateError('Unexpected company request');
    return [
      {
        'tenant': {'name': 'Moda Oriente'},
        'access_active': true,
        'active_branches': 2,
        'plan': {'name': 'Básico', 'max_branches': 2},
      },
    ];
  }
}
