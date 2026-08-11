import 'package:flutter/material.dart';

import 'core/theme/wave_theme.dart';
import 'features/shell/app_shell.dart';

class WaveApp extends StatelessWidget {
  const WaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wave',
      debugShowCheckedModeBanner: false,
      theme: WaveTheme.light,
      home: const AppShell(),
    );
  }
}
