import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../core/privacy/privacy_controller.dart';

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
      final report = await ref
          .read(scheduleRepositoryProvider)
          .processDueAutoPostsDetailed();
      if (!mounted) return;
      if (report.posted > 0) {
        ref.invalidate(activityEntriesProvider);
        ref.invalidate(transactionEntriesProvider);
        ref.invalidate(accountBalancesProvider);
        ref.invalidate(totalsProvider);
        ref.invalidate(scheduleForecastProvider);
        ref.invalidate(cashFlowInsightProvider);
        ref.invalidate(dashboardMetricsProvider);
      }
      if (report.posted > 0 || report.failures.isNotEmpty) {
        final parts = <String>[
          if (report.posted > 0)
            '${report.posted} planned item(s) posted when Wave opened.',
          if (report.failures.isNotEmpty)
            '${report.failures.length} item(s) could not be posted. Review Upcoming.',
        ];
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(parts.join(' '))));
      }
    } catch (_) {
      // A resume-time refresh must never prevent the app from unlocking.
    }
  }

  Future<void> _unlock() async {
    var success = false;
    try {
      success = await ref
          .read(privacyProvider.notifier)
          .unlockWithPin(_pin.text);
    } on PrivacyLockoutException catch (error) {
      if (!mounted) return;
      setState(() => _error = _lockoutMessage(error.remaining));
      return;
    }
    if (!mounted) return;
    setState(() {
      _error = success ? null : 'Incorrect PIN';
      if (success) _pin.clear();
    });
    if (success) await _offerRecoveryMigration();
  }

  Future<void> _unlockWithBiometrics() async {
    final controller = ref.read(privacyProvider.notifier);
    final success = await controller.unlockWithBiometrics();
    if (!success && mounted) {
      setState(() {
        _error = controller.lastBiometricError ?? 'Biometric unlock failed.';
      });
    }
    if (success && mounted) await _offerRecoveryMigration();
  }

  Future<void> _offerRecoveryMigration() async {
    if (ref.read(privacyProvider).recoveryAvailable || !mounted) return;
    final create = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recovery code required'),
        content: const Text(
          'This PIN was created by an earlier Wave version. Create and save a recovery code so a forgotten PIN cannot permanently block your data.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Create recovery code'),
          ),
        ],
      ),
    );
    if (create != true || !mounted) return;
    final code = await ref
        .read(privacyProvider.notifier)
        .regenerateRecoveryCode();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save your recovery code'),
        content: SelectableText(
          code
              .replaceAllMapped(
                RegExp(r'.{4}'),
                (match) => '${match.group(0)}-',
              )
              .replaceFirst(RegExp(r'-$'), ''),
          style: Theme.of(
            dialogContext,
          ).textTheme.titleLarge?.copyWith(letterSpacing: 2),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('I saved it'),
          ),
        ],
      ),
    );
  }

  Future<void> _recover() async {
    final recovery = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Use recovery code'),
        content: TextField(
          controller: recovery,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Recovery code'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, recovery.text),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
    recovery.dispose();
    if (code == null || !mounted) return;
    var success = false;
    try {
      success = await ref
          .read(privacyProvider.notifier)
          .unlockWithRecoveryCode(code);
    } on PrivacyLockoutException catch (error) {
      if (!mounted) return;
      setState(() => _error = _lockoutMessage(error.remaining));
      return;
    }
    if (!mounted) return;
    setState(() => _error = success ? null : 'Invalid recovery code');
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unlocked. Change your PIN in Privacy settings.'),
        ),
      );
    }
  }

  String _lockoutMessage(Duration remaining) {
    final seconds = remaining.inSeconds + 1;
    if (seconds >= 60) {
      return 'Too many attempts. Try again in ${(seconds / 60).ceil()} minute(s).';
    }
    return 'Too many attempts. Try again in $seconds seconds.';
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
                              if (privacy.recoveryAvailable)
                                TextButton(
                                  onPressed: _recover,
                                  child: const Text(
                                    'Forgot PIN? Use recovery code',
                                  ),
                                ),
                              if (privacy.biometricEnabled) ...[
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: _unlockWithBiometrics,
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
