import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../shell/app_shell.dart';
import 'onboarding_screen.dart';

class AppBootstrap extends ConsumerWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(onboardingCompleteProvider)
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Wave could not initialize: $error'),
              ),
            ),
          ),
          data: (complete) =>
              complete ? const AppShell() : const OnboardingScreen(),
        );
  }
}
