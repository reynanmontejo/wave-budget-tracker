import 'package:flutter/material.dart';

Future<bool> confirmAdd(
  BuildContext context, {
  required String title,
  required List<(String, String)> details,
  String confirmLabel = 'Confirm and add',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please review the details before saving.'),
            const SizedBox(height: 16),
            for (final (label, value) in details)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 88,
                      child: Text(
                        label,
                        style: TextStyle(
                          color: Theme.of(
                            dialogContext,
                          ).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ??
    false;
