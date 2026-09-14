import 'package:flutter/widgets.dart';

import 'package:drapemind_mobile/app/drapemind_app.dart';
import 'package:drapemind_mobile/core/config/api_config.dart';

export 'package:drapemind_mobile/app/drapemind_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.init();
  runApp(const DrapeMindApp());
}
