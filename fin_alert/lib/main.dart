import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/fin_alert_app.dart';
import 'application/providers.dart';
import 'bootstrap/app_bootstrap.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final overrides = await AppBootstrap.buildOverrides();
  await NotificationService.init();

  final container = ProviderContainer(overrides: overrides);
  await container.read(mailSyncServiceProvider).signInSilently();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const FinAlertApp(),
    ),
  );
}
