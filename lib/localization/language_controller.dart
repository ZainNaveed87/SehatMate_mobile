import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import 'app_language.dart';

abstract interface class ProfileLanguageSync {
  bool get canSyncProfileLanguage;
  PatientProfile? get currentProfile;
  Future<PatientProfile?> fetchProfile();
  Future<PatientProfile> updateProfile(PatientProfile profile);
}

class AuthProfileLanguageSync implements ProfileLanguageSync {
  const AuthProfileLanguageSync(this.session);

  final AuthSession session;

  @override
  bool get canSyncProfileLanguage =>
      session.isAuthenticated && !session.isGuest;

  @override
  PatientProfile? get currentProfile => session.profile;

  @override
  Future<PatientProfile?> fetchProfile() => session.fetchProfile();

  @override
  Future<PatientProfile> updateProfile(PatientProfile profile) =>
      session.updateProfile(profile);
}

class LanguageController extends ChangeNotifier {
  LanguageController._()
    : _profileSync = AuthProfileLanguageSync(AuthSession.instance);

  @visibleForTesting
  LanguageController.forTesting({ProfileLanguageSync? profileSync})
    : _profileSync = profileSync;

  static final LanguageController instance = LanguageController._();

  static const String _storageKey = 'sehatmate_app_language';

  // Compatibility with any older preference code that used this key.
  static const String _legacyStorageKey = 'app_language';

  AppLanguage _language = AppLanguage.english;
  bool _initialized = false;
  final ProfileLanguageSync? _profileSync;

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

    await reconcileWithServerProfile();
  }

  Future<void> setLanguage(
    AppLanguage language, {
    bool syncToServer = true,
  }) async {
    final changed = _language != language || !_initialized;

    if (changed) {
      _language = language;
      _initialized = true;
      notifyListeners();
    }

    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_storageKey, language.storageValue),
      prefs.setString(_legacyStorageKey, language.storageValue),
    ]);

    if (syncToServer) {
      await syncServerPreferredLanguage(language);
    }
  }

  Future<void> setFromStorageValue(String value) =>
      setLanguage(AppLanguageX.fromStorage(value));

  Future<void> setFromServerPreferredLanguage(
    String value, {
    bool syncToServer = false,
  }) {
    return setLanguage(
      AppLanguageX.fromServerPreferredLanguage(value),
      syncToServer: syncToServer,
    );
  }

  Future<bool> reconcileWithServerProfile() async {
    final sync = _profileSync;
    if (sync == null || !sync.canSyncProfileLanguage) return false;

    try {
      final profile = sync.currentProfile ?? await sync.fetchProfile();
      if (profile == null) return false;

      await setFromServerPreferredLanguage(
        profile.preferredLanguage,
        syncToServer: false,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> syncServerPreferredLanguage(AppLanguage language) async {
    final sync = _profileSync;
    if (sync == null || !sync.canSyncProfileLanguage) return false;

    try {
      final profile = sync.currentProfile ?? await sync.fetchProfile();
      if (profile == null) return false;

      final preferredLanguage = language.serverPreferredLanguage;
      if (profile.preferredLanguage == preferredLanguage) return true;

      await sync.updateProfile(
        profile.copyWith(preferredLanguage: preferredLanguage),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
