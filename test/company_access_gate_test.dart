import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/datos/servicios/auth_service.dart';
import 'package:drapemind_mobile/paquetes/saas/company_access_gate.dart';
import 'package:drapemind_mobile/paquetes/saas/subscription_screen.dart';

class AccessApi extends ApiClient {
  bool active = true;
  bool malformed = false;
  int calls = 0;
  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    calls++;
    if (malformed) throw const FormatException('fixture');
    return path == '/saas/plans'
        ? []
        : {
            'access_active': active,
            'tenant': {'name': 'Empresa de prueba'},
            'subscription': null,
          };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('CU-05 rechecks company access after returning to the app', (
    tester,
  ) async {
    final api = AccessApi();
    final auth = AuthService();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(
          home: CompanyAccessGate(
            apiClient: api,
            child: const Text('Tienda autorizada'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tienda autorizada'), findsOneWidget);
    api.active = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(SubscriptionScreen), findsOneWidget);
    expect(find.text('Tienda autorizada'), findsNothing);
  });
  testWidgets(
    'CU-05 malformed response offers retry instead of an endless spinner',
    (tester) async {
      final api = AccessApi()..malformed = true;
      final auth = AuthService();
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: auth,
          child: MaterialApp(
            home: CompanyAccessGate(
              apiClient: api,
              child: const Text('Tienda'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reintentar'), findsOneWidget);
      api.malformed = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Tienda'), findsOneWidget);
    },
  );
  test(
    'CU-05 secure storage failure never falls back to plaintext preferences',
    () async {
      SharedPreferences.setMockInitialValues({});
      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'unavailable');
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await expectLater(
        ApiClient().setToken('fixture-token'),
        throwsA(isA<ApiException>()),
      );
      expect(
        (await SharedPreferences.getInstance()).getString(
          'drapemind_auth_token',
        ),
        isNull,
      );
    },
  );
}
