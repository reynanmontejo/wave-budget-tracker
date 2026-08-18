import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/appearance_preferences.dart';
import '../../data/providers.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            'Wave theme',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          for (final theme in WaveThemeChoice.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ThemeChoice(
                theme: theme,
                selected: appearance.theme == theme,
                onTap: () =>
                    ref.read(appearanceProvider.notifier).setTheme(theme),
              ),
            ),
          const SizedBox(height: 18),
          Card(
            child: SwitchListTile(
              value: appearance.gentleMotion,
              onChanged: (value) =>
                  ref.read(appearanceProvider.notifier).setGentleMotion(value),
              secondary: const Icon(Icons.animation_rounded),
              title: const Text(
                'Gentle motion',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Subtle in-page and dashboard transitions. Device reduced-motion settings always take priority.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final WaveThemeChoice theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (name, description, colors) = switch (theme) {
      WaveThemeChoice.oceanLight => (
        'Ocean Light',
        'Airy blue with bright surfaces',
        const [Color(0xFF5B8DEF), Color(0xFFE8F0FE), Colors.white],
      ),
      WaveThemeChoice.deepBlue => (
        'Deep Blue',
        'Richer contrast with cool blue depth',
        const [Color(0xFF3977D5), Color(0xFFDCEAFF), Color(0xFFECF3FC)],
      ),
      WaveThemeChoice.calmNight => (
        'Calm Night',
        'Low-light navy surfaces',
        const [Color(0xFF82B1FF), Color(0xFF203A60), Color(0xFF101A29)],
      ),
    };
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final color in colors)
                    Container(
                      width: 22,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        border: Border.all(color: Colors.black12),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? Theme.of(context).colorScheme.primary : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
