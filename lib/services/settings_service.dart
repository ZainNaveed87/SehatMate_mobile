import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsException implements Exception {
  const SettingsException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class SettingsPreferenceStore {
  Future<bool?> readBool(String key);
  Future<void> writeBool(String key, bool value);
}

class SharedPreferencesSettingsStore implements SettingsPreferenceStore {
  const SharedPreferencesSettingsStore();

  @override
  Future<bool?> readBool(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key);
  }

  @override
  Future<void> writeBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setBool(key, value);
    if (!saved) {
      throw const SettingsException('Preference could not be saved.');
    }
  }
}

class SettingsService extends ChangeNotifier {
  SettingsService._() : _store = const SharedPreferencesSettingsStore();

  @visibleForTesting
  SettingsService.forTesting({SettingsPreferenceStore? store})
    : _store = store ?? const SharedPreferencesSettingsStore();

  static final SettingsService instance = SettingsService._();

  static const simpleCareModeStorageKey = 'sehatmate_simple_care_mode_enabled';

  final SettingsPreferenceStore _store;

  bool _initialized = false;
  bool _simpleCareModeEnabled = false;
  bool _savingSimpleCareMode = false;
  bool _loadFailed = false;

  bool get initialized => _initialized;
  bool get simpleCareModeEnabled => _simpleCareModeEnabled;
  bool get savingSimpleCareMode => _savingSimpleCareMode;
  bool get loadFailed => _loadFailed;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _simpleCareModeEnabled =
          await _store.readBool(simpleCareModeStorageKey) ?? false;
      _loadFailed = false;
    } catch (_) {
      _simpleCareModeEnabled = false;
      _loadFailed = true;
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> setSimpleCareMode(bool enabled) async {
    if (_initialized && _simpleCareModeEnabled == enabled) return;

    final previous = _simpleCareModeEnabled;
    _initialized = true;
    _simpleCareModeEnabled = enabled;
    _savingSimpleCareMode = true;
    notifyListeners();

    try {
      await _store.writeBool(simpleCareModeStorageKey, enabled);
      _loadFailed = false;
    } catch (_) {
      _simpleCareModeEnabled = previous;
      throw const SettingsException('Preference could not be saved.');
    } finally {
      _savingSimpleCareMode = false;
      notifyListeners();
    }
  }
}
