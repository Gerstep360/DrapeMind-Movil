import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/core/theme/app_theme.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/datos/servicios/auth_service.dart';
import 'package:drapemind_mobile/paquetes/saas/subscription_screen.dart';
import 'support/golden_assets.dart';

class AdminFixture extends AuthService {
  @override
  bool get isAdmin => true;
}

class BillingFixture extends ApiClient {
  @override
  Future<dynamic> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 20),
  }) async => {};
  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final plan = {
      'id': 1,
      'code': 'BASIC',
      'name': 'Básico',
      'max_branches': 2,
      'currency': 'bob',
      'monthly_amount_minor': 9900,
      'annual_amount_minor': 99000,
      'checkout_available': true,
      'annual_checkout_available': true,
      'active': true,
      'features': {
        'products_sales': true,
        'reservations': true,
        'offline': true,
        'reports': true,
        'ai_reports': false,
      },
    };
    return path == '/saas/plans'
        ? [plan]
        : {
            'tenant': {'name': 'Moda Oriente'},
            'plan': plan,
            'active_branches': 2,
            'access_active': true,
            'portal_available': false,
            'subscription': {
              'source': 'ADMINISTRATIVE',
              'ends_at': '2027-10-18T00:00:00Z',
            },
          };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadGoldenFonts);
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'Company billing fits ${width.toInt()}px and switches annual pricing',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final auth = AdminFixture();
        addTearDown(auth.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider<AuthService>.value(
            value: auth,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.luxuryTheme,
              home: SubscriptionScreen(apiClient: BillingFixture()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Moda Oriente'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (width == 390) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/saas_billing_390.png'),
          );
        }
        await tester.tap(find.text('Anual'));
        await tester.pumpAndSettle();
        expect(find.text('BOB 990.00 / año'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
