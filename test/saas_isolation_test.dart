import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drapemind_mobile/core/services/company_service.dart';
import 'package:drapemind_mobile/core/services/offline_catalog.dart';

String token(int user, int tenant) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': '$user', 'tid': tenant, 'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000})))}.signature';
Map<String, dynamic> license({bool offline = true, bool expired = false}) => {
  'access_active': true,
  'plan': {
    'features': {'offline': offline},
  },
  'subscription': {
    'ends_at': DateTime.now()
        .add(Duration(days: expired ? -1 : 30))
        .toIso8601String(),
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OfflineCatalog.active.value = false;
  });
  test(
    'offline catalog and license stay within their tenant and account',
    () async {
      final ownerA = OfflineCatalog.owner(token(1, 1));
      final ownerB = OfflineCatalog.owner(token(2, 2));
      await OfflineCatalog.save(ownerA, '/saas/me', 'license', license());
      await OfflineCatalog.save(ownerA, '/catalog/products', 'catalog', [
        {'name': 'A only'},
      ]);
      expect(
        await OfflineCatalog.read(ownerB, '/catalog/products', 'catalog'),
        isNull,
      );
      expect(
        await OfflineCatalog.read(ownerA, '/catalog/products', 'catalog'),
        [
          {'name': 'A only'},
        ],
      );
      expect(OfflineCatalog.active.value, isTrue);
      expect(
        await OfflineCatalog.read(
          OfflineCatalog.owner(token(3, 1)),
          '/catalog/products',
          'catalog',
        ),
        isNull,
      );
    },
  );
  test(
    'an expired or disabled offline license never returns cached data',
    () async {
      final owner = OfflineCatalog.owner(token(1, 1));
      await OfflineCatalog.save(owner, '/catalog/products', 'catalog', [1]);
      for (final state in [
        license(expired: true),
        license(offline: false),
        {...license(), 'access_active': false},
      ]) {
        await OfflineCatalog.save(owner, '/saas/me', 'license', state);
        expect(
          await OfflineCatalog.read(owner, '/catalog/products', 'catalog'),
          isNull,
        );
      }
    },
  );
  test('financial and personal records are not an offline catalog', () async {
    final owner = OfflineCatalog.owner(token(1, 1));
    await OfflineCatalog.save(owner, '/saas/me', 'license', license());
    for (final path in ['/payments', '/orders', '/users/me/addresses']) {
      await OfflineCatalog.save(owner, path, path, {'private': true});
      expect(await OfflineCatalog.read(owner, path, path), isNull);
    }
  });
  test('opaque and legacy tokens cannot select an offline company', () {
    expect(OfflineCatalog.owner('opaque'), isNull);
    expect(
      OfflineCatalog.owner(
        'header.${base64Url.encode(utf8.encode('{"sub":"1"}'))}.signature',
      ),
      isNull,
    );
  });
  test('company identifiers are normalized and reject paths', () async {
    await CompanyService.select('  Moda-Oriente  ');
    expect(await CompanyService.selected(), 'moda-oriente');
    expect(
      () => CompanyService.select('../another-company'),
      throwsFormatException,
    );
    expect(await CompanyService.selected(), 'moda-oriente');
  });
}
