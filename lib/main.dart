import 'package:flutter/material.dart';

import 'app.dart';
import 'localization/language_bootstrap.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.instance.initialize();
  await AuthSession.instance.initialize();

  runApp(
    LanguageBootstrap(
      builder: (context, language) => const SehatRouteApp(),
    ),
  );
}