import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wave/core/privacy/privacy_controller.dart';
import 'package:wave/data/database/app_database.dart';

final class _MemoryCredentials implements PrivacyCredentialStore {
  final values = <String, String>{};

  @override
  Future<bool> contains(String key) async => values.containsKey(key);
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late _MemoryCredentials credentials;
  late PrivacyController controller;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    credentials = _MemoryCredentials();
    controller = PrivacyController(database, storage: credentials);
    await controller.load();
  });

  tearDown(() async {
    controller.dispose();
    await database.close();
  });

  test('new PIN uses versioned derivation and unlocks', () async {
    final recovery = await controller.setPin('2468');

    expect(credentials.values['wave_pin_digest'], startsWith('v2:'));
    expect(recovery, hasLength(16));
    expect(await controller.unlockWithPin('2468'), isTrue);
  });

  test('repeated failures trigger a persistent delay', () async {
    await controller.setPin('2468');

    expect(await controller.unlockWithPin('0000'), isFalse);
    expect(await controller.unlockWithPin('0000'), isFalse);
    expect(await controller.unlockWithPin('0000'), isFalse);
    expect(await controller.unlockWithPin('0000'), isFalse);
    await expectLater(
      controller.unlockWithPin('2468'),
      throwsA(isA<PrivacyLockoutException>()),
    );
  });

  test('legacy PIN verifier migrates after successful unlock', () async {
    final salt = List<int>.generate(16, (index) => index);
    final digest = sha256.convert([...salt, ...utf8.encode('2468')]).toString();
    credentials.values['wave_pin_digest'] = '${base64Encode(salt)}:$digest';

    expect(await controller.unlockWithPin('2468'), isTrue);
    expect(credentials.values['wave_pin_digest'], startsWith('v2:'));
  });
}
