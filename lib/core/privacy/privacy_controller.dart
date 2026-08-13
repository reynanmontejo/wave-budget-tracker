import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../../data/database/app_database.dart';

final class PrivacyState {
  const PrivacyState({
    this.loaded = false,
    this.lockEnabled = false,
    this.biometricEnabled = false,
    this.hideWhenBackgrounded = true,
    this.timeoutMinutes = 1,
    this.locked = false,
  });
  final bool loaded;
  final bool lockEnabled;
  final bool biometricEnabled;
  final bool hideWhenBackgrounded;
  final int timeoutMinutes;
  final bool locked;

  PrivacyState copyWith({
    bool? loaded,
    bool? lockEnabled,
    bool? biometricEnabled,
    bool? hideWhenBackgrounded,
    int? timeoutMinutes,
    bool? locked,
  }) => PrivacyState(
    loaded: loaded ?? this.loaded,
    lockEnabled: lockEnabled ?? this.lockEnabled,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    hideWhenBackgrounded: hideWhenBackgrounded ?? this.hideWhenBackgrounded,
    timeoutMinutes: timeoutMinutes ?? this.timeoutMinutes,
    locked: locked ?? this.locked,
  );
}

final class PrivacyController extends StateNotifier<PrivacyState> {
  PrivacyController(
    this.database, {
    FlutterSecureStorage? storage,
    LocalAuthentication? authentication,
  }) : storage = storage ?? const FlutterSecureStorage(),
       authentication = authentication ?? LocalAuthentication(),
       super(const PrivacyState()) {
    load();
  }

  final AppDatabase database;
  final FlutterSecureStorage storage;
  final LocalAuthentication authentication;
  DateTime? _backgroundedAt;
  static const _pinKey = 'wave_pin_digest';

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
    );
  }

  Future<void> setPin(String pin) async {
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      throw const FormatException('PIN must contain 4 to 8 digits.');
    }
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final digest = sha256.convert([...salt, ...utf8.encode(pin)]).toString();
    await storage.write(key: _pinKey, value: '${base64Encode(salt)}:$digest');
    await database.setPreference('privacy_lock_enabled', 'true');
    state = state.copyWith(lockEnabled: true, locked: false);
  }

  Future<bool> unlockWithPin(String pin) async {
    final stored = await storage.read(key: _pinKey);
    if (stored == null) return false;
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    final digest = sha256.convert([
      ...base64Decode(parts.first),
      ...utf8.encode(pin),
    ]).toString();
    if (digest != parts.last) return false;
    state = state.copyWith(locked: false);
    return true;
  }

  Future<bool> unlockWithBiometrics() async {
    try {
      final success = await authentication.authenticate(
        localizedReason: 'Unlock your Wave budget',
        biometricOnly: true,
      );
      if (success) state = state.copyWith(locked: false);
      return success;
    } catch (_) {
      return false;
    }
  }

  Future<void> disableLock() async {
    await storage.delete(key: _pinKey);
    await database.setPreference('privacy_lock_enabled', 'false');
    await setBiometrics(false);
    state = state.copyWith(lockEnabled: false, locked: false);
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
