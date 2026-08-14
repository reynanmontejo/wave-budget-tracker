import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/wave_theme.dart';
import '../../data/providers.dart';
import '../transactions/add_transaction_sheet.dart';
import '../home/home_screen.dart';
import '../insights/insights_hub_screen.dart';
import '../plan/plan_hub_screen.dart';
import '../transactions/transactions_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  int _previousIndex = 0;
  late final AnimationController _waveController;

  static const _destinations = <Widget>[
    HomeScreen(),
    TransactionsScreen(),
    SizedBox.shrink(),
    PlanHubScreen(),
    InsightsHubScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _select(int index) async {
    if (index == 2) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const AddTransactionSheet(),
      );
      return;
    }
    if (index == _index) return;
    setState(() {
      _previousIndex = _index;
      _index = index;
    });
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (ref.read(appearanceProvider).gentleMotion && !reduceMotion) {
      _waveController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gentleMotion = ref.watch(
      appearanceProvider.select((value) => value.gentleMotion),
    );
    final motionEnabled =
        gentleMotion && !MediaQuery.disableAnimationsOf(context);
    final duration = motionEnabled
        ? const Duration(milliseconds: 220)
        : Duration.zero;
    final movingForward = _index > _previousIndex;
    return Scaffold(
      body: Stack(
        children: [
          for (var index = 0; index < _destinations.length; index++)
            if (index != 2)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: index != _index,
                  child: TickerMode(
                    enabled: index == _index,
                    child: AnimatedOpacity(
                      key: ValueKey('shell-page-$index'),
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      opacity: index == _index ? 1 : 0,
                      child: AnimatedSlide(
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        offset: index == _index
                            ? Offset.zero
                            : Offset(
                                index == _previousIndex
                                    ? (movingForward ? -0.025 : 0.025)
                                    : 0,
                                0,
                              ),
                        child: _destinations[index],
                      ),
                    ),
                  ),
                ),
              ),
          if (motionEnabled)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, _) => CustomPaint(
                    painter: _NavigationWavePainter(
                      progress: Curves.easeInOut.transform(
                        _waveController.value,
                      ),
                      movingForward: movingForward,
                      color: WaveColors.primary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle, color: WaveColors.primary, size: 40),
            label: 'Add',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note_rounded),
            label: 'Plan',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Insights',
          ),
        ],
      ),
    );
  }
}

class _NavigationWavePainter extends CustomPainter {
  const _NavigationWavePainter({
    required this.progress,
    required this.movingForward,
    required this.color,
  });

  final double progress;
  final bool movingForward;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final opacity = (1 - (progress - .5).abs() * 2) * .16;
    final travel = movingForward ? progress : 1 - progress;
    final center = size.width * travel;
    final paint = Paint()..color = color.withValues(alpha: opacity);
    final path = Path()
      ..moveTo(center - size.width * .7, size.height)
      ..cubicTo(
        center - size.width * .45,
        size.height - 76,
        center - size.width * .2,
        size.height - 20,
        center,
        size.height - 54,
      )
      ..cubicTo(
        center + size.width * .2,
        size.height - 88,
        center + size.width * .45,
        size.height - 28,
        center + size.width * .7,
        size.height - 64,
      )
      ..lineTo(center + size.width * .7, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _NavigationWavePainter oldDelegate) =>
      progress != oldDelegate.progress ||
      movingForward != oldDelegate.movingForward ||
      color != oldDelegate.color;
}
