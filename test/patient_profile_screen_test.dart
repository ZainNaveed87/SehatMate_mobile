import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/core/app_routes.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
import 'package:sehatmate_ai/screens/support_screens.dart';
import 'package:sehatmate_ai/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'PatientProfileScreen renders real profile and no demo sections',
    (tester) async {
      await _pumpProfile(
        tester,
        session: _FakeProfileSession(
          profile: _profile(),
        ),
      );

      expect(find.text('Sara Khan'), findsWidgets);
      expect(find.text('sara@test.com'), findsOneWidget);
      expect(find.text('Not added'), findsWidgets);
      expect(find.text('اردو'), findsOneWidget);
      expect(find.text('Care links'), findsOneWidget);
      expect(find.text('Care Plans'), findsWidgets);
      expect(find.text('Documents'), findsWidgets);
      expect(find.text('Progress'), findsWidgets);
      expect(find.text('Family Care'), findsWidgets);
      expect(find.text('Teach-Back'), findsWidgets);

      expect(find.text('Ali Khan'), findsNothing);
      expect(find.text('Karachi'), findsNothing);
      expect(find.text('Daily routine & support'), findsNothing);
      expect(find.text('Caregiver support'), findsNothing);
      expect(find.textContaining('Ahmed'), findsNothing);
    },
  );

  testWidgets(
    'PatientProfileScreen saves optional age and city honestly',
    (tester) async {
      final session = _FakeProfileSession(
        profile: _profile(
          preferredLanguage: 'English',
        ),
      );

      await _pumpProfile(
        tester,
        session: session,
      );

      await tester.enterText(
        find.byKey(
          const Key('profile_name_field'),
        ),
        'Zain Patient',
      );

      final saveButton = find.byKey(
        const Key('profile_save_button'),
      );

      expect(
        saveButton,
        findsOneWidget,
      );

      final button = tester.widget<FilledButton>(
        saveButton,
      );

      expect(
        button.onPressed,
        isNotNull,
      );

      button.onPressed!.call();

      await tester.pumpAndSettle();

      expect(
        session.updatedProfiles,
        hasLength(1),
      );

      expect(
        session.updatedProfiles.single.patientName,
        'Zain Patient',
      );

      expect(
        session.updatedProfiles.single.ageGroup,
        '',
      );

      expect(
        session.updatedProfiles.single.city,
        '',
      );

      expect(
        session.updatedProfiles.single.preferredLanguage,
        'English',
      );

      expect(
        find.text('Profile updated'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'PatientProfileScreen blocks duplicate save submissions',
    (tester) async {
      final completer = Completer<PatientProfile>();

      final session = _FakeProfileSession(
        profile: _profile(),
        updateCompleter: completer,
      );

      await _pumpProfile(
        tester,
        session: session,
      );

      final saveButton = find.byKey(
        const Key('profile_save_button'),
      );

      expect(
        saveButton,
        findsOneWidget,
      );

      final firstButton = tester.widget<FilledButton>(
        saveButton,
      );

      expect(
        firstButton.onPressed,
        isNotNull,
      );

      // First save starts.
      firstButton.onPressed!.call();

      await tester.pump();

      expect(
        session.updateCalls,
        1,
      );

      // Button must be disabled while save is pending.
      final buttonWhileSaving = tester.widget<FilledButton>(
        saveButton,
      );

      expect(
        buttonWhileSaving.onPressed,
        isNull,
      );

      expect(
        session.updateCalls,
        1,
      );

      // Finish the pending request.
      completer.complete(
        _profile(
          patientName: 'Sara Khan',
        ),
      );

      // Do not use pumpAndSettle here because
      // this test intentionally had a pending Future.
      await tester.pump();

      await tester.pump(
        const Duration(milliseconds: 500),
      );

      expect(
        session.updateCalls,
        1,
      );
    },
  );

  testWidgets(
    'PatientProfileScreen keeps success hidden on failed save',
    (tester) async {
      final session = _FakeProfileSession(
        profile: _profile(
          preferredLanguage: 'English',
        ),
        updateError: const AuthException(
          'Server rejected profile.',
        ),
      );

      await _pumpProfile(
        tester,
        session: session,
      );

      final saveButton = find.byKey(
        const Key('profile_save_button'),
      );

      expect(
        saveButton,
        findsOneWidget,
      );

      final button = tester.widget<FilledButton>(
        saveButton,
      );

      expect(
        button.onPressed,
        isNotNull,
      );

      button.onPressed!.call();

      await tester.pumpAndSettle();

      expect(
        find.text('Server rejected profile.'),
        findsOneWidget,
      );

      expect(
        find.text('Profile updated'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'PatientProfileScreen requires sign in before loading profile',
    (tester) async {
      final session = _FakeProfileSession(
        isAuthenticated: false,
      );

      await _pumpProfile(
        tester,
        session: session,
      );

      expect(
        find.text(
          'Sign in to view your patient profile',
        ),
        findsOneWidget,
      );

      expect(
        session.fetchCalls,
        0,
      );

      expect(
        find.text('Ali Khan'),
        findsNothing,
      );
    },
  );
}

Future<void> _pumpProfile(
  WidgetTester tester, {
  required ProfileSession session,
}) async {
  await tester.pumpWidget(
    LanguageScope(
      controller: LanguageController.forTesting(),
      child: MaterialApp(
        routes: {
          AppRoutes.auth: (_) => const Scaffold(
                body: Text('Auth destination'),
              ),
          AppRoutes.carePlans: (_) => const Scaffold(
                body: Text('Care Plans destination'),
              ),
          AppRoutes.documents: (_) => const Scaffold(
                body: Text('Documents destination'),
              ),
          AppRoutes.progress: (_) => const Scaffold(
                body: Text('Progress destination'),
              ),
          AppRoutes.family: (_) => const Scaffold(
                body: Text('Family destination'),
              ),
          AppRoutes.teachBack: (_) => const Scaffold(
                body: Text('Teach-Back destination'),
              ),
        },
        home: PatientProfileScreen(
          session: session,
        ),
      ),
    ),
  );

  await tester.pump();
  await tester.pumpAndSettle();
}

PatientProfile _profile({
  String patientName = 'Sara Khan',
  String preferredLanguage = 'Urdu',
}) {
  return PatientProfile(
    usingFor: 'Myself',
    patientName: patientName,
    ageGroup: '',
    city: '',
    preferredLanguage: preferredLanguage,
    accessibilityMode: 'Standard',
    caregiverSupport: false,
    onboardingCompleted: true,
  );
}

class _FakeProfileSession extends ChangeNotifier
    implements ProfileSession {
  _FakeProfileSession({
    this.isAuthenticated = true,
    PatientProfile? profile,
    this.updateError,
    this.updateCompleter,
  }) : _profile = profile;

  PatientProfile? _profile;

  final Object? updateError;
  final Completer<PatientProfile>? updateCompleter;

  final updatedProfiles = <PatientProfile>[];

  var fetchCalls = 0;
  var updateCalls = 0;

  @override
  final bool isAuthenticated;

  @override
  bool get isGuest => false;

  @override
  AuthUser? get user => isAuthenticated
      ? const AuthUser(
          id: 'user-1',
          name: 'Sara Account',
          email: 'sara@test.com',
        )
      : null;

  @override
  PatientProfile? get profile => _profile;

  @override
  bool get canAccessApp => isAuthenticated || isGuest;

  @override
  bool get needsOnboarding => false;

  @override
  Future<PatientProfile> completeOnboarding({
    required String usingFor,
    required String patientName,
    required String ageGroup,
    required String city,
    required String preferredLanguage,
    required String accessibilityMode,
    required bool caregiverSupport,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PatientProfile?> fetchProfile() async {
    fetchCalls += 1;
    return _profile;
  }

  @override
  Future<PatientProfile> updateProfile(
    PatientProfile profile,
  ) async {
    updateCalls += 1;

    updatedProfiles.add(profile);

    if (updateError != null) {
      throw updateError!;
    }

    if (updateCompleter != null) {
      return updateCompleter!.future;
    }

    _profile = profile;

    notifyListeners();

    return profile;
  }
}