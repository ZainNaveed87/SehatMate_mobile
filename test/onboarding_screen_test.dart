import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/core/app_routes.dart';
import 'package:sehatmate_ai/localization/app_language.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
import 'package:sehatmate_ai/screens/onboarding_screen.dart';
import 'package:sehatmate_ai/services/auth_service.dart';
import 'package:sehatmate_ai/services/notification_service.dart';
import 'package:sehatmate_ai/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'Onboarding uses useful setup questions without old UI options',
    (tester) async {
      await _pumpOnboarding(
        tester,
        session: _FakeProfileSession(),
      );

      expect(
        find.text('Who are you using SehatMate for?'),
        findsOneWidget,
      );
      expect(find.text('Ali Khan'), findsNothing);
      expect(find.text('Karachi'), findsNothing);

      await _next(tester);

      expect(
        find.text('Add the basic profile'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Only the name is required. Age group and city can stay blank.',
        ),
        findsOneWidget,
      );

      await _next(tester);

      expect(
        find.text('Choose the app language'),
        findsOneWidget,
      );

      await _next(tester);

      expect(
        find.text('What should SehatMate help with first?'),
        findsOneWidget,
      );

      await _next(tester);

      expect(
        find.text('Do you have care documents ready?'),
        findsOneWidget,
      );

      await _next(tester);

      expect(
        find.text('Reminders for confirmed care tasks'),
        findsOneWidget,
      );

      await _tapVisible(
        tester,
        find.byKey(
          const Key('onboarding_reminders_later'),
        ),
      );

      await _next(tester);

      expect(
        find.text('Would a simpler care view help?'),
        findsOneWidget,
      );

      expect(find.text('Accessibility'), findsNothing);
      expect(find.text('Large Text'), findsNothing);
      expect(find.text('Voice Guidance'), findsNothing);
      expect(
        find.text('Caregiver support available'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Onboarding saves profile and opens upload flow when requested',
    (tester) async {
      final session = _FakeProfileSession();
      final store = _MemoryOnboardingStore();
      final controller = LanguageController.forTesting();

      await _pumpOnboarding(
        tester,
        session: session,
        store: store,
        languageController: controller,
      );

      // Step 1 -> Step 2
      await _next(tester);

      // Step 2 -> Step 3
      await _next(tester);

      // Select Roman Urdu
      await _tapVisible(
        tester,
        find.byKey(
          const Key('onboarding_language_roman_urdu'),
        ),
      );

      // Step 3 -> Step 4
      await _next(tester);

      // Select task tracking goal
      await _tapVisible(
        tester,
        find.byKey(
          const Key('onboarding_goal_track_tasks'),
        ),
      );

      // Step 4 -> Step 5
      await _next(tester);

      // Select document upload
      await _tapVisible(
        tester,
        find.byKey(
          const Key('onboarding_document_upload'),
        ),
      );

      // Step 5 -> Step 6
      await _next(tester);

      // Choose reminders later
      await _tapVisible(
        tester,
        find.byKey(
          const Key('onboarding_reminders_later'),
        ),
      );

      // Step 6 -> Step 7
      await _next(tester);

      // Finish onboarding
      await _next(tester);

      expect(session.completeCalls, 1);
      expect(
        session.completedProfile!.patientName,
        'Sara Account',
      );
      expect(session.completedProfile!.ageGroup, '');
      expect(session.completedProfile!.city, '');
      expect(
        session.completedProfile!.preferredLanguage,
        'Roman Urdu',
      );

      expect(store.documentIntent, 'upload');
      expect(store.goals, contains('track_tasks'));
      expect(
        controller.language,
        AppLanguage.romanUrdu,
      );

      expect(
        find.text('New Care Plan destination'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Onboarding requests reminders and persists Simple Care mode',
    (tester) async {
      var permissionRequests = 0;

      final settingsStore = _MemorySettingsStore();
      final settings = SettingsService.forTesting(
        store: settingsStore,
      );
      final store = _MemoryOnboardingStore();
      final session = _FakeProfileSession();

      await _pumpOnboarding(
        tester,
        session: session,
        settings: settings,
        store: store,
        reminderPermissionRequester: () async {
          permissionRequests += 1;

          return const NotificationPermissionSnapshot(
            supported: true,
            notificationsEnabled: true,
            exactAlarmEnabled: true,
          );
        },
      );

      // Step 1 -> Step 2
      await _next(tester);

      // Step 2 -> Step 3
      await _next(tester);

      // Step 3 -> Step 4
      await _next(tester);

      // Step 4 -> Step 5
      await _next(tester);

      // Step 5 -> Step 6
      await _next(tester);

      // Enable reminders
      await _tapVisible(
        tester,
        find.byKey(
          const Key('onboarding_reminders_yes'),
        ),
      );

      // Step 6 -> Step 7
      await _next(tester);

      // Enable Simple Care
      await _tapVisible(
        tester,
        find.byKey(
          const Key('onboarding_simple_care_switch'),
        ),
      );

      // Finish
      await _next(tester);

      expect(permissionRequests, 1);
      expect(settingsStore.value, isTrue);
      expect(store.remindersRequested, isTrue);

      expect(
        session.completedProfile!.accessibilityMode,
        'Simple Care Mode',
      );

      expect(
        find.text('Dashboard destination'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Onboarding final submit is guarded while saving',
    (tester) async {
      final completer = Completer<PatientProfile>();

      final session = _FakeProfileSession(
        completeCompleter: completer,
      );

      await _pumpOnboarding(
        tester,
        session: session,
      );

      await _moveToFinalStep(tester);

      final finishButton = find.byKey(
        const Key('onboarding_next_button'),
      );

      await _makeVisible(
        tester,
        finishButton,
      );

      // First submit starts.
      await tester.tap(finishButton);
      await tester.pump();

      expect(session.completeCalls, 1);

      // While saving, the button should be disabled.
      expect(
        tester.widget<FilledButton>(finishButton).onPressed,
        isNull,
      );

      // Second tap must not submit again.
      await tester.tap(finishButton);
      await tester.pump();

      expect(session.completeCalls, 1);

      // Complete pending save.
      completer.complete(
        session.completedProfile ?? _profile(),
      );

      await tester.pumpAndSettle();

      expect(session.completeCalls, 1);
    },
  );
}

Future<void> _pumpOnboarding(
  WidgetTester tester, {
  required _FakeProfileSession session,
  SettingsService? settings,
  OnboardingPreferenceStore? store,
  ReminderPermissionRequester? reminderPermissionRequester,
  LanguageController? languageController,
}) async {
  await tester.pumpWidget(
    LanguageScope(
      controller:
          languageController ??
          LanguageController.forTesting(),
      child: MaterialApp(
        routes: {
          AppRoutes.auth: (_) => const Scaffold(
                body: Text('Auth destination'),
              ),
          AppRoutes.dashboard: (_) => const Scaffold(
                body: Text('Dashboard destination'),
              ),
          AppRoutes.carePlanNew: (_) => const Scaffold(
                body: Text('New Care Plan destination'),
              ),
        },
        home: OnboardingScreen(
          session: session,
          settingsService:
              settings ??
              SettingsService.forTesting(
                store: _MemorySettingsStore(),
              ),
          preferenceStore:
              store ?? _MemoryOnboardingStore(),
          reminderPermissionRequester:
              reminderPermissionRequester ??
              () async =>
                  const NotificationPermissionSnapshot(
                    supported: true,
                    notificationsEnabled: true,
                    exactAlarmEnabled: true,
                  ),
        ),
      ),
    ),
  );

  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> _makeVisible(
  WidgetTester tester,
  Finder finder,
) async {
  expect(finder, findsOneWidget);

  await tester.ensureVisible(finder);
  await tester.pump();
}

Future<void> _tapVisible(
  WidgetTester tester,
  Finder finder,
) async {
  await _makeVisible(
    tester,
    finder,
  );

  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _next(
  WidgetTester tester,
) async {
  await _tapVisible(
    tester,
    find.byKey(
      const Key('onboarding_next_button'),
    ),
  );
}

Future<void> _moveToFinalStep(
  WidgetTester tester,
) async {
  // Step 1 -> Step 2
  await _next(tester);

  // Step 2 -> Step 3
  await _next(tester);

  // Step 3 -> Step 4
  await _next(tester);

  // Step 4 -> Step 5
  await _next(tester);

  // Step 5 -> Step 6
  await _next(tester);

  // Step 6 requires a reminder choice.
  await _tapVisible(
    tester,
    find.byKey(
      const Key('onboarding_reminders_later'),
    ),
  );

  // Step 6 -> Step 7
  await _next(tester);
}

PatientProfile _profile() {
  return const PatientProfile(
    usingFor: 'Myself',
    patientName: 'Sara Account',
    ageGroup: '',
    city: '',
    preferredLanguage: 'English',
    accessibilityMode: 'Standard',
    caregiverSupport: false,
    onboardingCompleted: true,
  );
}

class _FakeProfileSession extends ChangeNotifier
    implements ProfileSession {
  _FakeProfileSession({
    this.completeCompleter,
  });

  final Completer<PatientProfile>? completeCompleter;

  PatientProfile? completedProfile;

  var completeCalls = 0;

  @override
  AuthUser? get user => const AuthUser(
        id: 'user-1',
        name: 'Sara Account',
        email: 'sara@test.com',
      );

  @override
  PatientProfile? get profile => completedProfile;

  @override
  bool get isAuthenticated => true;

  @override
  bool get isGuest => false;

  @override
  bool get canAccessApp => true;

  @override
  bool get needsOnboarding => true;

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
    completeCalls += 1;

    completedProfile = PatientProfile(
      usingFor: usingFor,
      patientName: patientName.trim(),
      ageGroup: ageGroup,
      city: city.trim(),
      preferredLanguage: preferredLanguage,
      accessibilityMode: accessibilityMode,
      caregiverSupport: caregiverSupport,
      onboardingCompleted: true,
    );

    if (completeCompleter != null) {
      return completeCompleter!.future;
    }

    return Future.value(
      completedProfile!,
    );
  }

  @override
  Future<PatientProfile?> fetchProfile() async {
    return completedProfile;
  }

  @override
  Future<PatientProfile> updateProfile(
    PatientProfile profile,
  ) async {
    completedProfile = profile;
    return profile;
  }
}

class _MemorySettingsStore
    implements SettingsPreferenceStore {
  bool? value;

  @override
  Future<bool?> readBool(
    String key,
  ) async {
    return value;
  }

  @override
  Future<void> writeBool(
    String key,
    bool value,
  ) async {
    this.value = value;
  }
}

class _MemoryOnboardingStore
    implements OnboardingPreferenceStore {
  Set<String> goals = const {};

  String? documentIntent;

  bool? remindersRequested;

  @override
  Future<void> save({
    required Set<String> goals,
    required String documentIntent,
    required bool remindersRequested,
  }) async {
    this.goals = Set<String>.of(goals);
    this.documentIntent = documentIntent;
    this.remindersRequested = remindersRequested;
  }
}