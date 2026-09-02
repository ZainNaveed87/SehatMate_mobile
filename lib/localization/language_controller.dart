import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';

class LanguageController extends ChangeNotifier {
  LanguageController._();

  static final LanguageController instance = LanguageController._();

  static const String _storageKey = 'sehatmate_app_language';

  // Compatibility with any older preference code that used this key.
  static const String _legacyStorageKey = 'app_language';

  AppLanguage _language = AppLanguage.english;
  bool _initialized = false;

  AppLanguage get language => _language;
  bool get initialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final saved =
        prefs.getString(_storageKey) ?? prefs.getString(_legacyStorageKey);

    _language = AppLanguageX.fromStorage(saved);
    _initialized = true;
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language && _initialized) return;

    _language = language;
    _initialized = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_storageKey, language.storageValue),
      prefs.setString(_legacyStorageKey, language.storageValue),
    ]);
  }

  Future<void> setFromStorageValue(String value) =>
      setLanguage(AppLanguageX.fromStorage(value));
}
