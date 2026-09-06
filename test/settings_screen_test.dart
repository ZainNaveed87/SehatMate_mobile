import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/localization/app_language.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
import 'package:sehatmate_ai/screens/support_screens.dart';
import 'package:sehatmate_ai/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Settings renders real supported sections only', (tester) async {
    final settings = SettingsService.forTesting(store: _MemorySettingsStore());
    await _pumpSettings(tester, settings: settings);

    expect(find.text('Care experience'), findsOneWidget);
    expect(find.text('Language'), findsWidgets);
    expect(find.text('Notifications & reminders'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Privacy & data'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Simple Care Mode'), findsOneWidget);
    expect(
      find.text('Reminders come from confirmed care items'),
      findsOneWidget,
    );
    expect(find.text('Logout'), findsOneWidget);

    expect(find.text('Large text'), findsNothing);
    expect(find.text('Voice guidance'), findsNothing);
    expect(find.text('Reduced motion'), findsNothing);
    expect(find.text('Export my data'), findsNothing);
    expect(find.text('Delete account'), findsNothing);
    expect(find.text('Medicine reminders'), findsNothing);
  });

  testWidgets('Simple Care toggle reflects and changes real preference', (
    tester,
  ) async {
    final store = _MemorySettingsStore();
    final settings = SettingsService.forTesting(store: store);
    await _pumpSettings(tester, settings: settings);

    Switch simpleCareSwitch() {
      return tester.widget<Switch>(
        find.byKey(const Key('settings_simple_care_toggle')),
      );
    }

    expect(simpleCareSwitch().value, isFalse);
    expect(store.value, isNull);

    await tester.tap(find.byKey(const Key('settings_simple_care_toggle')));
    await tester.pumpAndSettle();

    expect(settings.simpleCareModeEnabled, isTrue);
    expect(store.value, isTrue);
    expect(find.text('Simple Care is on'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings_simple_care_toggle')));
    await tester.pumpAndSettle();

    expect(settings.simpleCareModeEnabled, isFalse);
    expect(store.value, isFalse);
  });

  testWidgets('language choices render and current language is reflected', (
    tester,
  ) async {
    final controller = LanguageController.forTesting();
    final settings = SettingsService.forTesting(store: _MemorySettingsStore());

    await _pumpSettings(
      tester,
      settings: settings,
      languageController: controller,
    );

    expect(find.text('Current language: English'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings_language_dropdown')));
    await tester.pumpAndSettle();

    expect(find.text('English'), findsWidgets);
    expect(find.text('اردو'), findsWidgets);
    expect(find.text('Roman Urdu'), findsWidgets);

    await tester.tap(find.text('Roman Urdu').last);
    await tester.pumpAndSettle();

    expect(controller.language, AppLanguage.romanUrdu);
    expect(find.text('Current language: Roman Urdu'), findsOneWidget);
  });

  testWidgets('sign out control is wired to a real enabled action', (
    tester,
  ) async {
    final settings = SettingsService.forTesting(store: _MemorySettingsStore());
    await _pumpSettings(tester, settings: settings);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('settings_sign_out_button')),
    );

    expect(button.onPressed, isNotNull);
  });
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  required SettingsService settings,
  LanguageController? languageController,
}) async {
  await tester.pumpWidget(
    LanguageScope(
      controller: languageController ?? LanguageController.forTesting(),
      child: MaterialApp(home: SettingsScreen(settingsService: settings)),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

class _MemorySettingsStore implements SettingsPreferenceStore {
  bool? value;

  @override
  Future<bool?> readBool(String key) async => value;

  @override
  Future<void> writeBool(String key, bool value) async {
    this.value = value;
  }
}
