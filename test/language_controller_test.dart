import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/localization/app_language.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeProfileLanguageSync implements ProfileLanguageSync {
  _FakeProfileLanguageSync({PatientProfile? profile}) : _profile = profile;

  PatientProfile? _profile;
  final updatedProfiles = <PatientProfile>[];

  @override
  bool get canSyncProfileLanguage => true;

  @override
  PatientProfile? get currentProfile => _profile;

  @override
  Future<PatientProfile?> fetchProfile() async => _profile;

  @override
  Future<PatientProfile> updateProfile(PatientProfile profile) async {
    updatedProfiles.add(profile);
    _profile = profile;
    return profile;
  }
}

PatientProfile _profile({String preferredLanguage = 'English'}) {
  return PatientProfile(
    usingFor: 'Myself',
    patientName: 'Ali Khan',
    ageGroup: '60 - 70',
    city: 'Karachi',
    preferredLanguage: preferredLanguage,
    accessibilityMode: 'Standard',
    caregiverSupport: true,
    onboardingCompleted: true,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'Roman Urdu app preference syncs through profile update shape',
    () async {
      final sync = _FakeProfileLanguageSync(profile: _profile());
      final controller = LanguageController.forTesting(profileSync: sync);

      await controller.initialize();
      await controller.setLanguage(AppLanguage.romanUrdu);

      expect(controller.language, AppLanguage.romanUrdu);
      expect(sync.updatedProfiles, hasLength(1));
      expect(sync.updatedProfiles.single.preferredLanguage, 'Roman Urdu');
      expect(sync.updatedProfiles.single.patientName, 'Ali Khan');
    },
  );

  test(
    'authenticated bootstrap reconciles local language from server profile',
    () async {
      SharedPreferences.setMockInitialValues({
        'sehatmate_app_language': 'english',
        'app_language': 'english',
      });
      final controller = LanguageController.forTesting(
        profileSync: _FakeProfileLanguageSync(
          profile: _profile(preferredLanguage: 'Roman Urdu'),
        ),
      );

      await controller.initialize();

      expect(controller.language, AppLanguage.romanUrdu);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('sehatmate_app_language'), 'roman_urdu');
      expect(prefs.getString('app_language'), 'roman_urdu');
    },
  );

  test('server preferred language mapping preserves selector labels', () {
    expect(AppLanguage.english.displayName, 'English');
    expect(AppLanguage.urdu.displayName, 'اردو');
    expect(AppLanguage.romanUrdu.displayName, 'Roman Urdu');
    expect(AppLanguage.english.serverPreferredLanguage, 'English');
    expect(AppLanguage.urdu.serverPreferredLanguage, 'Urdu');
    expect(AppLanguage.romanUrdu.serverPreferredLanguage, 'Roman Urdu');
  });
}
