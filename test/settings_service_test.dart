import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Simple Care Mode defaults to off', () async {
    final service = SettingsService.forTesting();

    await service.initialize();

    expect(service.simpleCareModeEnabled, isFalse);
    expect(service.initialized, isTrue);
  });

  test('enabling and disabling Simple Care Mode updates state', () async {
    final service = SettingsService.forTesting();
    await service.initialize();

    await service.setSimpleCareMode(true);
    expect(service.simpleCareModeEnabled, isTrue);

    await service.setSimpleCareMode(false);
    expect(service.simpleCareModeEnabled, isFalse);
  });

  test('persisted true reloads as true', () async {
    SharedPreferences.setMockInitialValues({
      SettingsService.simpleCareModeStorageKey: true,
    });
    final service = SettingsService.forTesting();

    await service.initialize();

    expect(service.simpleCareModeEnabled, isTrue);
  });

  test('persisted false reloads as false', () async {
    SharedPreferences.setMockInitialValues({
      SettingsService.simpleCareModeStorageKey: false,
    });
    final service = SettingsService.forTesting();

    await service.initialize();

    expect(service.simpleCareModeEnabled, isFalse);
  });

  test('load failure fails safely to off', () async {
    final service = SettingsService.forTesting(
      store: _FailingSettingsStore(failRead: true),
    );

    await service.initialize();

    expect(service.simpleCareModeEnabled, isFalse);
    expect(service.loadFailed, isTrue);
  });

  test('write failure reverts the visible preference', () async {
    final store = _FailingSettingsStore(value: false, failWrite: true);
    final service = SettingsService.forTesting(store: store);
    await service.initialize();

    await expectLater(
      service.setSimpleCareMode(true),
      throwsA(isA<SettingsException>()),
    );

    expect(service.simpleCareModeEnabled, isFalse);
  });
}

class _FailingSettingsStore implements SettingsPreferenceStore {
  _FailingSettingsStore({
    this.value,
    this.failRead = false,
    this.failWrite = false,
  });

  bool? value;
  final bool failRead;
  final bool failWrite;

  @override
  Future<bool?> readBool(String key) async {
    if (failRead) throw StateError('read failed');
    return value;
  }

  @override
  Future<void> writeBool(String key, bool value) async {
    if (failWrite) throw StateError('write failed');
    this.value = value;
  }
}
