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

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;
  int _previousIndex = 0;

  static const _destinations = <Widget>[
    HomeScreen(),
    TransactionsScreen(),
    SizedBox.shrink(),
    PlanHubScreen(),
    InsightsHubScreen(),
  ];

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
                      child: TickerMode(
                        enabled: index == _index,
                        child: _destinations[index],
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
