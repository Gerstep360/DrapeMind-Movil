import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

import 'package:drapemind_mobile/app/drapemind_app.dart';
import 'package:drapemind_mobile/core/config/api_config.dart';
import 'package:drapemind_mobile/core/services/company_service.dart';
import 'package:drapemind_mobile/firebase_options.dart';

export 'package:drapemind_mobile/app/drapemind_app.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.init();
  await CompanyService.acceptStoreLink(
    WidgetsBinding.instance.platformDispatcher.defaultRouteName,
  );

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint(
      '[Firebase] Inicializacion con opciones explicitas: $e',
    );
    try {
      await Firebase.initializeApp();
    } catch (_) {}
  }

  runApp(const DrapeMindApp());
}
