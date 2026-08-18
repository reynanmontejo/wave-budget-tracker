final class WalletProviderPreset {
  const WalletProviderPreset({
    required this.key,
    required this.name,
    required this.colorValue,
  });

  final String key;
  final String name;
  final int colorValue;
}

const walletProviderPresets = <WalletProviderPreset>[
  WalletProviderPreset(key: 'gcash', name: 'GCash', colorValue: 0xFF3975D8),
  WalletProviderPreset(key: 'maya', name: 'Maya', colorValue: 0xFF3F8F70),
  WalletProviderPreset(
    key: 'shopeepay',
    name: 'ShopeePay',
    colorValue: 0xFFD86464,
  ),
  WalletProviderPreset(key: 'grabpay', name: 'GrabPay', colorValue: 0xFF269CA3),
];

WalletProviderPreset? walletProviderForKey(String? key) =>
    walletProviderPresets.where((provider) => provider.key == key).firstOrNull;

String walletProviderMonogram(String? providerName) {
  final clean = providerName?.trim() ?? '';
  return clean.isEmpty ? 'W' : clean.substring(0, 1).toUpperCase();
}
