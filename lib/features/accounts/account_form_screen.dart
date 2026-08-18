import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/money/money.dart';
import '../../core/widgets/confirm_add_dialog.dart';
import '../../data/database/app_database.dart';
import '../../data/management_repository.dart';
import '../../data/providers.dart';
import '../../data/wallet_providers.dart';
import 'account_card.dart';

class AccountFormScreen extends ConsumerStatefulWidget {
  const AccountFormScreen({this.initial, this.initialType, super.key});

  final AccountBalanceSummary? initial;
  final String? initialType;

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  static const _colors = <int>[
    0xFF5B8DEF,
    0xFF3F8F70,
    0xFF269CA3,
    0xFF7E6BC4,
    0xFFC28732,
    0xFFD86464,
  ];
  static const _icons = <String>[
    'wallet',
    'account_balance',
    'payments',
    'savings',
    'phone',
    'trending_up',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _balance;
  late final TextEditingController _customProvider;
  late final TextEditingController _identifierSuffix;
  late String _type;
  late String _walletProviderKey;
  late DateTime _openingDate;
  late String _iconKey;
  late int _colorValue;
  late bool _includeInNetWorth;
  bool _saving = false;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final account = widget.initial?.account;
    _name = TextEditingController(text: account?.name ?? '');
    _balance = TextEditingController(
      text: account == null
          ? ''
          : (account.openingBalanceMinor / 100).toStringAsFixed(2),
    );
    _type =
        account?.typeName ?? widget.initialType ?? supportedAccountTypes.first;
    _walletProviderKey =
        account?.walletProviderKey ??
        (_type == 'E-wallet' ? walletProviderPresets.first.key : 'custom');
    final preset = walletProviderForKey(_walletProviderKey);
    _customProvider = TextEditingController(
      text: preset == null && _type == 'E-wallet'
          ? (account?.walletProviderName ?? account?.name ?? '')
          : '',
    );
    _identifierSuffix = TextEditingController(
      text: account?.walletIdentifierSuffix ?? '',
    );
    _openingDate = account?.openingBalanceDate ?? DateTime.now();
    _iconKey = account?.iconKey ?? (_type == 'E-wallet' ? 'phone' : 'wallet');
    _colorValue = account?.colorValue ?? preset?.colorValue ?? _colors.first;
    _includeInNetWorth = account?.includeInNetWorth ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    _customProvider.dispose();
    _identifierSuffix.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editing
              ? 'Edit account'
              : _type == 'E-wallet'
              ? 'Add e-wallet'
              : 'Add account',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 130),
          children: [
            Text(
              _editing
                  ? 'Update how this account appears in Wave.'
                  : 'Create a place for cash, savings, or another balance.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              autofocus: !_editing,
              textInputAction: TextInputAction.next,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: _type == 'E-wallet'
                    ? 'Wallet nickname'
                    : 'Account name',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter an account name.'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [
                for (final type in supportedAccountTypes)
                  DropdownMenuItem(value: type, child: Text(type)),
              ],
              onChanged: _saving
                  ? null
                  : (value) => _changeType(value ?? _type),
            ),
            if (_type == 'E-wallet') ...[
              const SizedBox(height: 18),
              Text(
                'E-wallet provider',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final provider in walletProviderPresets)
                    ChoiceChip(
                      selected: _walletProviderKey == provider.key,
                      avatar: CircleAvatar(
                        backgroundColor: Color(provider.colorValue),
                        foregroundColor: Colors.white,
                        child: Text(
                          provider.name.substring(0, 1),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      label: Text(provider.name),
                      onSelected: _saving
                          ? null
                          : (_) => _chooseWalletProvider(provider),
                    ),
                  ChoiceChip(
                    selected: _walletProviderKey == 'custom',
                    avatar: const Icon(Icons.add_business_outlined, size: 18),
                    label: const Text('Other'),
                    onSelected: _saving
                        ? null
                        : (_) => setState(() => _walletProviderKey = 'custom'),
                  ),
                ],
              ),
              if (_walletProviderKey == 'custom') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customProvider,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Provider name',
                    hintText: 'Enter the e-wallet provider',
                  ),
                  validator: (value) =>
                      _type == 'E-wallet' &&
                          _walletProviderKey == 'custom' &&
                          (value == null || value.trim().isEmpty)
                      ? 'Enter the wallet provider.'
                      : null,
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _identifierSuffix,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Last four digits (optional)',
                  helperText: 'Wave never needs your full wallet number.',
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.offline_bolt_outlined),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tracked manually in Wave. No provider account will be connected.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _balance,
              enabled: !(_editing && _type == 'E-wallet'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: _type == 'E-wallet' && !_editing
                    ? 'Current wallet value'
                    : 'Opening balance',
                prefixText: '₱ ',
                helperText: _editing && _type == 'E-wallet'
                    ? 'Use Reconcile value from wallet details to correct this value.'
                    : 'This is the balance before recorded activity.',
              ),
              validator: (value) {
                final amount = Money.parseMajorUnits(
                  value == null || value.trim().isEmpty ? '0' : value,
                );
                if (amount == null) return 'Enter a valid amount.';
                if (amount < 0) return 'Opening balance cannot be negative.';
                return null;
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Opening-balance date'),
              subtitle: Text(DateFormat.yMMMd().format(_openingDate)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _saving ? null : _chooseDate,
            ),
            const SizedBox(height: 18),
            Text(
              'Card icon',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in _icons)
                  ChoiceChip(
                    selected: _iconKey == key,
                    tooltip: key.replaceAll('_', ' '),
                    label: Icon(accountIconFor(key), size: 21),
                    onSelected: _saving
                        ? null
                        : (_) => setState(() => _iconKey = key),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Card color',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final value in _colors)
                  Semantics(
                    button: true,
                    selected: _colorValue == value,
                    label: 'Choose account color',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: _saving
                          ? null
                          : () => setState(() => _colorValue = value),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Color(value),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _colorValue == value
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: _colorValue == value
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _includeInNetWorth,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _includeInNetWorth = value),
              title: const Text('Include in total balance'),
              subtitle: const Text(
                'Turn this off for an account you want to track separately.',
              ),
            ),
            if (_editing) ...[
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _type == 'E-wallet'
                              ? 'Use Reconcile value from wallet details when the value in Wave differs from your wallet app.'
                              : 'Changing the opening balance changes the current balance by the same difference. Recorded transactions remain unchanged.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_editing ? Icons.save_outlined : Icons.add),
            label: Text(_editing ? 'Save' : 'Add'),
          ),
        ),
      ),
    );
  }

  String? get _walletProviderName {
    if (_type != 'E-wallet') return null;
    return walletProviderForKey(_walletProviderKey)?.name ??
        _customProvider.text.trim();
  }

  void _changeType(String value) {
    setState(() {
      _type = value;
      if (value == 'E-wallet') {
        if (_walletProviderKey == 'custom' &&
            _customProvider.text.trim().isEmpty) {
          final provider = walletProviderPresets.first;
          _walletProviderKey = provider.key;
          _colorValue = provider.colorValue;
        }
        _iconKey = 'phone';
      }
    });
  }

  void _chooseWalletProvider(WalletProviderPreset provider) {
    setState(() {
      _walletProviderKey = provider.key;
      _colorValue = provider.colorValue;
      _iconKey = 'phone';
    });
  }

  Future<void> _chooseDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDate: _openingDate,
    );
    if (date != null) setState(() => _openingDate = date);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = Money.parseMajorUnits(
      _balance.text.trim().isEmpty ? '0' : _balance.text,
    )!;
    final currencyCode = widget.initial?.account.currencyCode ?? 'PHP';
    final details = <(String, String)>[
      ('Name', _name.text.trim()),
      ('Type', _type),
      ('Currency', currencyCode),
      ('Opening', Money(amount, currencyCode: currencyCode).format()),
      ('In total', _includeInNetWorth ? 'Yes' : 'No'),
    ];
    if (_type == 'E-wallet') {
      details.addAll([
        ('Provider', _walletProviderName!),
        ('Tracking', 'Manual • no provider connection'),
      ]);
    }
    if (_editing && _type != 'E-wallet') {
      final current = widget.initial!.account.openingBalanceMinor;
      final difference = amount - current;
      details.add((
        'Balance effect',
        '${difference > 0 ? '+' : ''}${Money(difference, currencyCode: currencyCode).format()}',
      ));
    }
    final confirmed = await confirmAdd(
      context,
      title: _editing ? 'Confirm account changes' : 'Confirm new account',
      details: details,
      confirmLabel: _editing ? 'Save changes' : 'Confirm and add',
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    try {
      final repository = ref.read(managementRepositoryProvider);
      if (_editing) {
        await repository.updateAccount(
          id: widget.initial!.account.id,
          name: _name.text,
          typeName: _type,
          openingBalanceMinor: amount,
          openingBalanceDate: _openingDate,
          iconKey: _iconKey,
          colorValue: _colorValue,
          includeInNetWorth: _includeInNetWorth,
          walletProviderName: _walletProviderName,
          walletProviderKey: _type == 'E-wallet' ? _walletProviderKey : null,
          walletIdentifierSuffix: _type == 'E-wallet'
              ? _identifierSuffix.text
              : null,
        );
      } else {
        await repository.createAccount(
          name: _name.text,
          typeName: _type,
          openingBalanceMinor: amount,
          openingBalanceDate: _openingDate,
          iconKey: _iconKey,
          colorValue: _colorValue,
          includeInNetWorth: _includeInNetWorth,
          walletProviderName: _walletProviderName,
          walletProviderKey: _type == 'E-wallet' ? _walletProviderKey : null,
          walletIdentifierSuffix: _type == 'E-wallet'
              ? _identifierSuffix.text
              : null,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(switch (error) {
              ArgumentError(:final message) =>
                message?.toString() ?? 'Check the account details.',
              StateError(:final message) => message,
              _ => 'Wave could not save this account. Please try again.',
            }),
          ),
        );
    }
  }
}
