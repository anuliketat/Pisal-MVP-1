import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../core/config/app_config.dart';
import '../features/home/home.dart';
import '../features/onboarding/onboarding.dart';

class FinAlertApp extends ConsumerWidget {
  const FinAlertApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return MaterialApp(
      title: 'Fin Alert',
      locale: const Locale('en', 'IN'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      home: _HomeGate(config: config),
    );
  }
}

class _HomeGate extends StatelessWidget {
  const _HomeGate({required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    if (config.onboardingDone) {
      return const HomeScreen();
    }
    return const OnboardingScreen();
  }
}
