import 'package:flutter/material.dart';

import 'core/theme/wave_theme.dart';
import 'data/providers.dart';
import 'features/onboarding/app_bootstrap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WaveApp extends ConsumerWidget {
  const WaveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    return MaterialApp(
      title: 'Wave',
      debugShowCheckedModeBanner: false,
      theme: WaveTheme.forChoice(appearance.theme),
      themeAnimationDuration: appearance.gentleMotion
          ? const Duration(milliseconds: 220)
          : Duration.zero,
      themeAnimationCurve: Curves.easeOutCubic,
      home: const AppBootstrap(),
    );
  }
}
