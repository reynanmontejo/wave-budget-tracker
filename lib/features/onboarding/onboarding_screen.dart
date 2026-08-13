import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money/money.dart';
import '../../core/theme/wave_theme.dart';
import '../../data/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _accountName = TextEditingController(text: 'Cash');
  final _openingBalance = TextEditingController();
  var _step = 0;
  var _accountType = 'Cash';
  var _saving = false;

  @override
  void dispose() {
    _accountName.dispose();
    _openingBalance.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final amount = Money.parseMajorUnits(
      _openingBalance.text.trim().isEmpty ? '0' : _openingBalance.text,
    );
    if (_accountName.text.trim().isEmpty || amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid account name and opening balance.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(onboardingRepositoryProvider)
          .complete(
            accountName: _accountName.text,
            accountType: _accountType,
            openingBalanceMinor: amount,
          );
      ref.invalidate(onboardingCompleteProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ArgumentError
                  ? error.message?.toString() ?? 'Check the account details.'
                  : 'Wave could not finish setup. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.waves_rounded,
                    color: WaveColors.primary,
                    size: 34,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Wave',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: WaveColors.primaryStrong,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _step == 0
                    ? const _WelcomeStep(key: ValueKey(0))
                    : _AccountStep(
                        key: const ValueKey(1),
                        accountName: _accountName,
                        openingBalance: _openingBalance,
                        accountType: _accountType,
                        onTypeChanged: (value) =>
                            setState(() => _accountType = value),
                      ),
              ),
              const Spacer(),
              Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: _saving ? null : () => setState(() => _step--),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _saving
                        ? null
                        : _step == 0
                        ? () => setState(() => _step = 1)
                        : _finish,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(150, 52),
                    ),
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(_step == 0 ? 'Get started' : 'Start using Wave'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({super.key});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 112,
        height: 112,
        decoration: const BoxDecoration(
          color: WaveColors.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.waves_rounded,
          color: WaveColors.primary,
          size: 64,
        ),
      ),
      const SizedBox(height: 28),
      Text(
        'Your money, in your hands',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 12),
      const Text(
        'Wave works fully offline. No account, no cloud, and no ads. Your financial records stay on this device.',
        textAlign: TextAlign.center,
        style: TextStyle(color: WaveColors.muted, fontSize: 16, height: 1.5),
      ),
      const SizedBox(height: 20),
      const _PrivacyPoint(
        icon: Icons.cloud_off_outlined,
        text: 'Works without internet',
      ),
      const _PrivacyPoint(
        icon: Icons.lock_outline_rounded,
        text: 'Private local storage',
      ),
      const _PrivacyPoint(
        icon: Icons.backup_outlined,
        text: 'You control your backups',
      ),
    ],
  );
}

class _PrivacyPoint extends StatelessWidget {
  const _PrivacyPoint({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: WaveColors.primaryStrong),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _AccountStep extends StatelessWidget {
  const _AccountStep({
    super.key,
    required this.accountName,
    required this.openingBalance,
    required this.accountType,
    required this.onTypeChanged,
  });
  final TextEditingController accountName;
  final TextEditingController openingBalance;
  final String accountType;
  final ValueChanged<String> onTypeChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Set up your first account',
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      const Text(
        'PHP is the default currency for this version. You can add more accounts later.',
        style: TextStyle(color: WaveColors.muted),
      ),
      const SizedBox(height: 24),
      TextField(
        controller: accountName,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(
          labelText: 'Account name',
          prefixIcon: Icon(Icons.account_balance_wallet_outlined),
        ),
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        initialValue: accountType,
        decoration: const InputDecoration(labelText: 'Account type'),
        items: const ['Cash', 'Bank', 'E-wallet', 'Savings']
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: (value) {
          if (value != null) onTypeChanged(value);
        },
      ),
      const SizedBox(height: 14),
      TextField(
        controller: openingBalance,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Opening balance',
          prefixText: '₱ ',
        ),
      ),
    ],
  );
}
