import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

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
                  await showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Save your recovery code'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Keep this outside your phone. It can unlock Wave if you forget your PIN, and it will not be shown again.',
                          ),
                          const SizedBox(height: 16),
                          SelectableText(
                            recoveryCode
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
