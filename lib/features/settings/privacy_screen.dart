import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../core/privacy/privacy_controller.dart';

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  Future<void> _showRecoveryCode(
    BuildContext context,
    String code,
  ) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Save your recovery code'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Keep this outside your phone. It can unlock Wave if you forget your PIN. Generating another code invalidates the previous one.',
          ),
          const SizedBox(height: 16),
          SelectableText(
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
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('I saved it'),
        ),
      ],
    ),
  );

  Future<String?> _askPin(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create app PIN'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 8,
          decoration: const InputDecoration(labelText: '4 to 8 digit PIN'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Enable lock'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<(String, String)?> _askPinChange(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: current,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Current PIN'),
            ),
            TextField(
              controller: next,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: const InputDecoration(labelText: 'New PIN'),
            ),
            TextField(
              controller: confirm,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: const InputDecoration(labelText: 'Confirm new PIN'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (next.text != confirm.text) return;
              Navigator.pop(dialogContext, (current.text, next.text));
            },
            child: const Text('Change PIN'),
          ),
        ],
      ),
    );
    current.dispose();
    next.dispose();
    confirm.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privacy = ref.watch(privacyProvider);
    final controller = ref.read(privacyProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SwitchListTile(
            title: const Text('App lock'),
            subtitle: const Text('Require a PIN when returning to Wave.'),
            value: privacy.lockEnabled,
            onChanged: (enabled) async {
              if (!enabled) {
                await controller.disableLock();
                return;
              }
              final pin = await _askPin(context);
              if (pin == null || !context.mounted) return;
              try {
                final recoveryCode = await controller.setPin(pin);
                if (context.mounted) {
                  await _showRecoveryCode(context, recoveryCode);
                }
              } on FormatException catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.message)));
                }
              }
            },
          ),
          if (privacy.lockEnabled)
            ListTile(
              leading: const Icon(Icons.password_rounded),
              title: const Text('Change PIN'),
              subtitle: const Text(
                'Requires your current PIN and creates a new recovery code.',
              ),
              onTap: () async {
                final values = await _askPinChange(context);
                if (values == null || !context.mounted) return;
                try {
                  final code = await controller.changePin(
                    currentPin: values.$1,
                    newPin: values.$2,
                  );
                  if (context.mounted) await _showRecoveryCode(context, code);
                } on PrivacyLockoutException catch (error) {
                  if (context.mounted) {
                    final minutes = (error.remaining.inSeconds / 60).ceil();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Too many attempts. Try again in $minutes minute(s).',
                        ),
                      ),
                    );
                  }
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                }
              },
            ),
          if (privacy.lockEnabled)
            ListTile(
              leading: const Icon(Icons.key_rounded),
              title: Text(
                privacy.recoveryAvailable
                    ? 'Regenerate recovery code'
                    : 'Create recovery code',
              ),
              subtitle: Text(
                privacy.recoveryAvailable
                    ? 'The existing recovery code will stop working.'
                    : 'Required for PIN recovery after upgrading Wave.',
              ),
              onTap: () async {
                final code = await controller.regenerateRecoveryCode();
                if (context.mounted) await _showRecoveryCode(context, code);
              },
            ),
          SwitchListTile(
            title: const Text('Biometric unlock'),
            subtitle: const Text(
              'Use fingerprint or face authentication when available.',
            ),
            value: privacy.biometricEnabled,
            onChanged: privacy.lockEnabled
                ? (enabled) async {
                    try {
                      await controller.setBiometrics(enabled);
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    }
                  }
                : null,
          ),
          SwitchListTile(
            title: const Text('Screen privacy protection'),
            subtitle: const Text(
              'Block screenshots and cover financial information in the app switcher.',
            ),
            value: privacy.hideWhenBackgrounded,
            onChanged: controller.setHideWhenBackgrounded,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: privacy.timeoutMinutes,
            decoration: const InputDecoration(
              labelText: 'Automatic lock timeout',
            ),
            items: const [
              DropdownMenuItem(value: 0, child: Text('Immediately')),
              DropdownMenuItem(value: 1, child: Text('After 1 minute')),
              DropdownMenuItem(value: 5, child: Text('After 5 minutes')),
              DropdownMenuItem(value: 15, child: Text('After 15 minutes')),
            ],
            onChanged: privacy.lockEnabled
                ? (value) {
                    if (value != null) controller.setTimeout(value);
                  }
                : null,
          ),
          const SizedBox(height: 20),
          const Text(
            'Your PIN is stored using secure device storage. Disabling app lock removes it. Backups never contain the PIN.',
          ),
        ],
      ),
    );
  }
}
