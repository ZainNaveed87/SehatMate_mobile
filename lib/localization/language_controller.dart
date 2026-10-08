import 'dart:async';
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
  Future<void>? _pendingLanguageWrite;

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
    bool persistBeforeNotify = false,
  }) {
    final changed = _language != language || !_initialized;
    // Publish the persistence barrier before notifying voice/UI listeners.
    // Serialize existing profile updates so rapid selections cannot save backwards.
    final previous = _pendingLanguageWrite;
    Future<void> persist() async {
      await _persistLanguage(
        language,
        syncToServer: syncToServer,
        requireProfileSync: persistBeforeNotify,
      );
      if (persistBeforeNotify && (_language != language || !_initialized)) {
        _language = language;
        _initialized = true;
        notifyListeners();
      }
    }

    final write = previous == null
        ? persist()
        : previous.then((_) => persist());
    final barrier = write.catchError((Object _) {});
    _pendingLanguageWrite = barrier;
    unawaited(
      barrier.then((_) {
        if (identical(_pendingLanguageWrite, barrier)) {
          _pendingLanguageWrite = null;
        }
      }),
    );

    if (changed && !persistBeforeNotify) {
      _language = language;
      _initialized = true;
      notifyListeners();
    }

    return write;
  }

  Future<void> _persistLanguage(
    AppLanguage language, {
    required bool syncToServer,
    required bool requireProfileSync,
  }) async {
    // Agent dropdowns publish only a confirmed preference. Reuse the same
    // authenticated profile flow and persistence queue as other language controls.
    if (requireProfileSync &&
        syncToServer &&
        _profileSync?.canSyncProfileLanguage == true &&
        !await syncServerPreferredLanguage(language)) {
      throw StateError('Language preference could not be saved');
    }
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_storageKey, language.storageValue),
      prefs.setString(_legacyStorageKey, language.storageValue),
    ]);

    if (syncToServer && !requireProfileSync) {
      await syncServerPreferredLanguage(language);
    }
  }

  /// A voice session must wait for the selected preference to reach the existing
  /// authenticated profile flow. The backend independently reads that profile.
  Future<bool> prepareVoiceLanguage(AppLanguage selected) async {
    await _pendingLanguageWrite;
    if (_language != selected) return false;
    return syncServerPreferredLanguage(selected);
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

      final updated = await sync.updateProfile(
        profile.copyWith(preferredLanguage: preferredLanguage),
      );
      return AppLanguageX.fromServerPreferredLanguage(
            updated.preferredLanguage,
          ) ==
          language;
    } catch (_) {
      return false;
    }
  }
}
