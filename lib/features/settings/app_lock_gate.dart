import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  final _pin = TextEditingController();
  bool _backgrounded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pin.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(privacyProvider.notifier);
    if (state == AppLifecycleState.resumed) {
      controller.resumed();
      _processDueAutoPosts();
      if (mounted) setState(() => _backgrounded = false);
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      controller.backgrounded();
      if (mounted) setState(() => _backgrounded = true);
    }
  }

  Future<void> _processDueAutoPosts() async {
    try {
      final posted = await ref
          .read(scheduleRepositoryProvider)
          .processDueAutoPosts();
      if (posted == 0 || !mounted) return;
      ref.invalidate(activityEntriesProvider);
      ref.invalidate(transactionEntriesProvider);
      ref.invalidate(accountBalancesProvider);
      ref.invalidate(totalsProvider);
      ref.invalidate(scheduleForecastProvider);
      ref.invalidate(cashFlowInsightProvider);
      ref.invalidate(dashboardMetricsProvider);
    } catch (_) {
      // A resume-time refresh must never prevent the app from unlocking.
    }
  }

  Future<void> _unlock() async {
    final success = await ref
        .read(privacyProvider.notifier)
        .unlockWithPin(_pin.text);
    if (!mounted) return;
    setState(() {
      _error = success ? null : 'Incorrect PIN';
      if (success) _pin.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final privacy = ref.watch(privacyProvider);
    final obscure =
        !privacy.loaded ||
        privacy.locked ||
        (_backgrounded && privacy.hideWhenBackgrounded);
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(excluding: obscure, child: widget.child),
        if (obscure)
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: !privacy.loaded
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            children: [
                              Icon(
                                Icons.water_drop_rounded,
                                size: 64,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Wave is locked',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 20),
                              TextField(
                                controller: _pin,
                                obscureText: true,
                                keyboardType: TextInputType.number,
                                onSubmitted: (_) => _unlock(),
                                decoration: InputDecoration(
                                  labelText: 'PIN',
                                  errorText: _error,
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: _unlock,
                                child: const Text('Unlock'),
                              ),
                              if (privacy.biometricEnabled) ...[
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () => ref
                                      .read(privacyProvider.notifier)
                                      .unlockWithBiometrics(),
                                  icon: const Icon(Icons.fingerprint),
                                  label: const Text('Use biometrics'),
                                ),
                              ],
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
