import 'dart:convert';
import 'dart:math';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

import '../../data/database/app_database.dart';

final class PrivacyLockoutException implements Exception {
  const PrivacyLockoutException(this.remaining);
  final Duration remaining;
}

abstract interface class PrivacyCredentialStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<bool> contains(String key);
}

final class SecurePrivacyCredentialStore implements PrivacyCredentialStore {
  SecurePrivacyCredentialStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
  @override
  Future<bool> contains(String key) => _storage.containsKey(key: key);
}

String _derivePinDigest((String, List<int>, int) input) {
  var bytes = <int>[...input.$2, ...utf8.encode(input.$1)];
  for (var index = 0; index < input.$3; index++) {
    bytes = sha256.convert(bytes).bytes;
  }
  return base64Encode(bytes);
}

final class PrivacyState {
  const PrivacyState({
    this.loaded = false,
    this.lockEnabled = false,
    this.biometricEnabled = false,
    this.hideWhenBackgrounded = true,
    this.timeoutMinutes = 1,
    this.locked = false,
    this.recoveryAvailable = false,
  });
  final bool loaded;
  final bool lockEnabled;
  final bool biometricEnabled;
  final bool hideWhenBackgrounded;
  final int timeoutMinutes;
  final bool locked;
  final bool recoveryAvailable;

  PrivacyState copyWith({
    bool? loaded,
    bool? lockEnabled,
    bool? biometricEnabled,
    bool? hideWhenBackgrounded,
    int? timeoutMinutes,
    bool? locked,
    bool? recoveryAvailable,
  }) => PrivacyState(
    loaded: loaded ?? this.loaded,
    lockEnabled: lockEnabled ?? this.lockEnabled,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    hideWhenBackgrounded: hideWhenBackgrounded ?? this.hideWhenBackgrounded,
    timeoutMinutes: timeoutMinutes ?? this.timeoutMinutes,
    locked: locked ?? this.locked,
    recoveryAvailable: recoveryAvailable ?? this.recoveryAvailable,
  );
}

final class PrivacyController extends StateNotifier<PrivacyState> {
  PrivacyController(
    this.database, {
    PrivacyCredentialStore? storage,
    LocalAuthentication? authentication,
  }) : storage = storage ?? SecurePrivacyCredentialStore(),
       authentication = authentication ?? LocalAuthentication(),
       super(const PrivacyState()) {
    load();
  }

  final AppDatabase database;
  final PrivacyCredentialStore storage;
  final LocalAuthentication authentication;
  DateTime? _backgroundedAt;
  static const _pinKey = 'wave_pin_digest';
  static const _recoveryKey = 'wave_recovery_digest';
  static const _failedAttemptsKey = 'wave_unlock_failed_attempts';
  static const _retryAtKey = 'wave_unlock_retry_at';
  static const _pinIterations = 20000;
  static const _privacyChannel = MethodChannel('wave/privacy');
  String? lastBiometricError;

  Future<void> load() async {
    final enabled = await database.preference('privacy_lock_enabled') == 'true';
    final timeout = int.tryParse(
      await database.preference('privacy_lock_timeout') ?? '',
    );
    state = state.copyWith(
      loaded: true,
      lockEnabled: enabled,
      biometricEnabled:
          await database.preference('privacy_biometric') == 'true',
      hideWhenBackgrounded:
          await database.preference('privacy_hide_background') != 'false',
      timeoutMinutes: timeout ?? 1,
      locked: enabled,
      recoveryAvailable: await storage.contains(_recoveryKey),
    );
    await _setNativeScreenProtection(state.hideWhenBackgrounded);
  }

  Future<String> setPin(String pin) async {
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      throw const FormatException('PIN must contain 4 to 8 digits.');
    }
    await _storePin(pin);
    final recoveryCode = await regenerateRecoveryCode();
    await database.setPreference('privacy_lock_enabled', 'true');
    state = state.copyWith(
      lockEnabled: true,
      locked: false,
      recoveryAvailable: true,
    );
    return recoveryCode;
  }

  Future<bool> unlockWithRecoveryCode(String code) async {
    await _enforceAttemptDelay();
    final stored = await storage.read(_recoveryKey);
    if (stored == null) {
      await _recordFailedAttempt();
      return false;
    }
    final normalized = code.replaceAll('-', '').trim().toUpperCase();
    final digest = sha256.convert(utf8.encode(normalized)).toString();
    if (!_constantTimeEquals(digest, stored)) {
      await _recordFailedAttempt();
      return false;
    }
    await _clearFailedAttempts();
    state = state.copyWith(locked: false);
    return true;
  }

  Future<String> regenerateRecoveryCode() async {
    final recoveryCode = _createRecoveryCode();
    await storage.write(
      _recoveryKey,
      sha256.convert(utf8.encode(recoveryCode)).toString(),
    );
    state = state.copyWith(recoveryAvailable: true);
    return recoveryCode;
  }

  Future<bool> unlockWithPin(String pin) async {
    await _enforceAttemptDelay();
    final stored = await storage.read(_pinKey);
    if (stored == null) {
      await _recordFailedAttempt();
      return false;
    }
    final parts = stored.split(':');
    var matches = false;
    var legacy = false;
    if (parts.length == 4 && parts.first == 'v2') {
      final iterations = int.tryParse(parts[1]);
      if (iterations != null) {
        final digest = await Isolate.run(
          () => _derivePinDigest((pin, base64Decode(parts[2]), iterations)),
        );
        matches = _constantTimeEquals(digest, parts[3]);
      }
    } else if (parts.length == 2) {
      legacy = true;
      final digest = sha256.convert([
        ...base64Decode(parts.first),
        ...utf8.encode(pin),
      ]).toString();
      matches = _constantTimeEquals(digest, parts.last);
    }
    if (!matches) {
      await _recordFailedAttempt();
      return false;
    }
    await _clearFailedAttempts();
    if (legacy) await _storePin(pin);
    state = state.copyWith(locked: false);
    return true;
  }

  Future<String> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    if (!await unlockWithPin(currentPin)) {
      throw StateError('Current PIN is incorrect.');
    }
    return setPin(newPin);
  }

  Future<bool> unlockWithBiometrics() async {
    lastBiometricError = null;
    try {
      final success = await authentication.authenticate(
        localizedReason: 'Unlock your Wave budget',
        biometricOnly: true,
      );
      if (success) {
        await _clearFailedAttempts();
        state = state.copyWith(locked: false);
      } else {
        lastBiometricError = 'Biometric authentication was not completed.';
      }
      return success;
    } catch (error) {
      lastBiometricError = 'Biometric unlock is unavailable: $error';
      return false;
    }
  }

  Future<void> disableLock() async {
    await storage.delete(_pinKey);
    await storage.delete(_recoveryKey);
    await _clearFailedAttempts();
    await database.setPreference('privacy_lock_enabled', 'false');
    await setBiometrics(false);
    state = state.copyWith(
      lockEnabled: false,
      locked: false,
      recoveryAvailable: false,
    );
  }

  Future<void> setBiometrics(bool enabled) async {
    if (enabled) {
      final supported = await authentication.isDeviceSupported();
      final available = await authentication.canCheckBiometrics;
      if (!supported || !available) {
        throw StateError(
          'Biometric authentication is not available or enrolled on this device.',
        );
      }
      final verified = await authentication.authenticate(
        localizedReason: 'Confirm biometrics for Wave unlock',
        biometricOnly: true,
      );
      if (!verified) throw StateError('Biometric verification was cancelled.');
    }
    await database.setPreference('privacy_biometric', enabled.toString());
    state = state.copyWith(biometricEnabled: enabled);
  }

  Future<void> setHideWhenBackgrounded(bool enabled) async {
    await database.setPreference('privacy_hide_background', enabled.toString());
    state = state.copyWith(hideWhenBackgrounded: enabled);
    await _setNativeScreenProtection(enabled);
  }

  String _createRecoveryCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final raw = List.generate(
      16,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    return raw;
  }

  Future<void> _storePin(String pin) async {
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final digest = await Isolate.run(
      () => _derivePinDigest((pin, salt, _pinIterations)),
    );
    await storage.write(
      _pinKey,
      'v2:$_pinIterations:${base64Encode(salt)}:$digest',
    );
  }

  Future<void> _enforceAttemptDelay() async {
    final raw = await storage.read(_retryAtKey);
    final retryAt = raw == null ? null : DateTime.tryParse(raw);
    if (retryAt == null) return;
    final remaining = retryAt.difference(DateTime.now().toUtc());
    if (remaining > Duration.zero) {
      throw PrivacyLockoutException(remaining);
    }
    await storage.delete(_retryAtKey);
  }

  Future<void> _recordFailedAttempt() async {
    final failures =
        (int.tryParse(await storage.read(_failedAttemptsKey) ?? '') ?? 0) + 1;
    await storage.write(_failedAttemptsKey, failures.toString());
    final delay = switch (failures) {
      >= 8 => const Duration(minutes: 5),
      >= 6 => const Duration(minutes: 1),
      >= 4 => const Duration(seconds: 15),
      _ => Duration.zero,
    };
    if (delay > Duration.zero) {
      await storage.write(
        _retryAtKey,
        DateTime.now().toUtc().add(delay).toIso8601String(),
      );
    }
  }

  Future<void> _clearFailedAttempts() async {
    await storage.delete(_failedAttemptsKey);
    await storage.delete(_retryAtKey);
  }

  bool _constantTimeEquals(String left, String right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
    }
    return difference == 0;
  }

  Future<void> _setNativeScreenProtection(bool enabled) async {
    try {
      await _privacyChannel.invokeMethod<void>('setScreenProtection', enabled);
    } on MissingPluginException {
      // Unit tests and non-Android platforms may not expose this channel.
    } on PlatformException {
      // The Flutter privacy overlay remains active as a safe fallback.
    }
  }

  Future<void> setTimeout(int minutes) async {
    await database.setPreference('privacy_lock_timeout', minutes.toString());
    state = state.copyWith(timeoutMinutes: minutes);
  }

  void backgrounded() => _backgroundedAt = DateTime.now();

  void resumed() {
    if (!state.lockEnabled || _backgroundedAt == null) return;
    final elapsed = DateTime.now().difference(_backgroundedAt!);
    if (state.timeoutMinutes == 0 ||
        elapsed >= Duration(minutes: state.timeoutMinutes)) {
      state = state.copyWith(locked: true);
    }
    _backgroundedAt = null;
  }
}
