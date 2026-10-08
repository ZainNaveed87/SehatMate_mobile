import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sehatmate_ai/features/agent/controllers/agent_controller.dart';
import 'package:sehatmate_ai/features/agent/models/agent_response.dart';
import 'package:sehatmate_ai/features/agent/screens/agent_screen.dart';
import 'package:sehatmate_ai/features/agent/services/agent_session_store.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_controller.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_scope.dart';
import 'package:sehatmate_ai/localization/app_language.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
import 'package:sehatmate_ai/services/auth_service.dart';
import 'voice_companion_controller_test.dart' as fixture;
import 'voice_language_switch_test.dart' as language_fixture;

void main() {
  late language_fixture.ProfileSync profile;
  late LanguageController languages;
  late language_fixture.LanguageBackend backend;
  late fixture.Transport transport;
  late fixture.Device device;
  late AgentController agent;
  late VoiceCompanionController voice;
  final selector = find.byKey(const ValueKey('agent_language_selector'));

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({
      'sehatroute_auth_token': 'test-token',
      'sehatroute_auth_user':
          '{"id":"user-1","name":"Test User","email":"test@example.com"}',
    });
    await AuthSession.instance.initialize();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({AgentSessionStore.key: '41'});
    profile = language_fixture.ProfileSync();
    languages = LanguageController.forTesting(profileSync: profile);
    backend = language_fixture.LanguageBackend(profile);
    transport = fixture.Transport();
    device = fixture.Device();
    agent = AgentController(client: fixture.Client());
    voice = VoiceCompanionController(
      backend: backend,
      transport: transport,
      agent: agent,
      authenticated: () => true,
      languagePreferences: languages,
      device: device,
      delay: (_) async {},
    );
  });
  tearDown(() async {
    await voice.end();
    voice.dispose();
    agent.dispose();
    languages.dispose();
  });

  Future<void> pumpApp(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(languages.initialize);
    await tester.pumpWidget(
      LanguageScope(
        controller: languages,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: Directionality(
              textDirection: context.appLanguage.textDirection,
              child: VoiceCompanionHost(controller: voice, child: child!),
            ),
          ),
          home: AgentScreen(voiceService: device),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 400));
    });
  }

  Future<void> choose(
    WidgetTester tester,
    AppLanguage language, {
    bool finish = true,
  }) async {
    await tester.tap(selector);
    await tester.pump(const Duration(milliseconds: 300));
    for (final label in ['English', 'اردو', 'Roman Urdu']) {
      expect(find.widgetWithText(MenuItemButton, label), findsOneWidget);
    }
    await tester.runAsync(() async {
      await tester.tap(
        find.byKey(ValueKey('agent_language_option_${language.storageValue}')),
      );
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    if (finish) {
      var complete = false;
      unawaited(voice.languageChangeComplete.then((_) => complete = true));
      for (var i = 0; i < 20 && !complete; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      }
      expect(complete, true, reason: 'Existing language rebind must complete');
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  for (final realtime in [false, true]) {
    testWidgets(
      '${realtime ? 'voice' : 'typing'} header has a readable accessible language dropdown',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await pumpApp(tester);
          if (realtime) {
            await tester.runAsync(() => voice.start(AppLanguage.english));
            await tester.pump(const Duration(milliseconds: 400));
            await tester.pump(const Duration(milliseconds: 400));
          }
          expect(selector.hitTestable(), findsOneWidget);
          expect(
            find.descendant(of: selector, matching: find.text('Language:')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: selector, matching: find.text('English')),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: selector,
              matching: find.byIcon(Icons.keyboard_arrow_down_rounded),
            ),
            findsOneWidget,
          );
          expect(tester.getSize(selector).height, greaterThanOrEqualTo(48));
          for (final icon in [
            Icons.language,
            Icons.language_rounded,
            Icons.language_outlined,
            Icons.public,
            Icons.public_rounded,
          ]) {
            expect(find.byIcon(icon), findsNothing);
          }
          await tester.pump();
          expect(
            tester.getSemantics(selector).getSemanticsData().label,
            contains('Language, currently English'),
          );
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets(
    'all three choices update one controller and preserve chat session/history',
    (tester) async {
      await pumpApp(tester);
      await tester.runAsync(
        () => agent.acceptVoiceResult(
          AgentResponse.fromJson(fixture.result),
          transcript: 'Keep this conversation',
        ),
      );
      await tester.pump();
      final history = agent.messages.map((m) => m.text).toList();
      for (final language in [
        AppLanguage.urdu,
        AppLanguage.romanUrdu,
        AppLanguage.english,
      ]) {
        await choose(tester, language);
        expect(languages.language, language);
        expect(
          profile.profile.preferredLanguage,
          language.serverPreferredLanguage,
        );
        final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
        expect(
          prefs.getString('sehatmate_app_language'),
          language.storageValue,
        );
        expect(prefs.getString('app_language'), language.storageValue);
        expect(
          find.descendant(
            of: selector,
            matching: find.text(language.displayName),
          ),
          findsOneWidget,
        );
        expect(agent.sessionId, '41');
        expect(agent.messages.map((m) => m.text), history);
      }
      expect(backend.calls, isEmpty);
    },
  );

  testWidgets(
    'voice dropdown reuses rebind, and the typing selector sees the same preference',
    (tester) async {
      await pumpApp(tester);
      await tester.runAsync(() => voice.start(AppLanguage.english));
      await tester.runAsync(voice.mute);
      await tester.pump(const Duration(milliseconds: 400));
      await choose(tester, AppLanguage.romanUrdu);
      expect(backend.calls, ['create:41', 'end', 'create:41']);
      expect(backend.preferencesAtCreate, ['English', 'Roman Urdu']);
      expect(voice.language, AppLanguage.romanUrdu);
      expect(voice.muted, true);
      expect(transport.mic, false);
      await tester.runAsync(voice.manual);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AgentScreen).hitTestable(), findsOneWidget);
      expect(
        find.descendant(of: selector, matching: find.text('Roman Urdu')),
        findsOneWidget,
      );
      await choose(tester, AppLanguage.urdu);
      expect(voice.state, 'manual');
      expect(transport.mic, false);
      expect(backend.preferencesAtCreate, ['English', 'Roman Urdu']);
      expect(agent.sessionId, '41');
    },
  );

  testWidgets(
    'a pending profile save keeps the confirmed value and disables repeated taps',
    (tester) async {
      await pumpApp(tester);
      profile.firstUpdate = Completer<void>();
      await choose(tester, AppLanguage.urdu, finish: false);
      expect(languages.language, AppLanguage.english);
      expect(
        find.descendant(of: selector, matching: find.text('English')),
        findsOneWidget,
      );
      expect(tester.widget<TextButton>(selector).onPressed, isNull);
      expect(profile.updates, 1);
      profile.firstUpdate!.complete();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 400));
      expect(languages.language, AppLanguage.urdu);
      expect(profile.updates, 1);
    },
  );

  testWidgets('keyboard layout preserves the pending selector save', (
    tester,
  ) async {
    await pumpApp(tester, scale: 1.8);
    profile.firstUpdate = Completer<void>();
    await choose(tester, AppLanguage.urdu, finish: false);
    expect(tester.widget<TextButton>(selector).onPressed, isNull);
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.widget<TextButton>(selector).onPressed, isNull);
    expect(languages.language, AppLanguage.english);
    expect(profile.updates, 1);
    profile.firstUpdate!.complete();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 400));
    expect(languages.language, AppLanguage.urdu);
  });

  for (final realtime in [false, true]) {
    testWidgets(
      'failed ${realtime ? 'voice' : 'typing'} preference save keeps the confirmed language and shows a safe error',
      (tester) async {
        await pumpApp(tester);
        if (realtime) {
          await tester.runAsync(() => voice.start(AppLanguage.english));
          await tester.pump(const Duration(milliseconds: 400));
        }
        profile.fail = true;
        await choose(tester, AppLanguage.urdu);
        expect(languages.language, AppLanguage.english);
        expect(profile.profile.preferredLanguage, 'English');
        expect(
          find.descendant(of: selector, matching: find.text('English')),
          findsOneWidget,
        );
        expect(
          find.text('Language could not be changed. Please try again.'),
          findsOneWidget,
        );
        expect(find.textContaining('profile unavailable'), findsNothing);
        final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
        expect(prefs.getString('sehatmate_app_language'), 'english');
        expect(backend.preferencesAtCreate, realtime ? ['English'] : isEmpty);
      },
    );
  }

  testWidgets(
    'Urdu selector and menu respect RTL with large text without overflow',
    (tester) async {
      await pumpApp(tester, scale: 1.8);
      await choose(tester, AppLanguage.urdu);
      expect(
        find.descendant(of: selector, matching: find.text('زبان:')),
        findsOneWidget,
      );
      expect(Directionality.of(tester.element(selector)), TextDirection.rtl);
      await tester.tap(selector);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.widgetWithText(MenuItemButton, 'اردو'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('typing selector remains fixed when conversation scrolls', (
    tester,
  ) async {
    await pumpApp(tester);
    for (var i = 0; i < 14; i++) {
      await tester.runAsync(
        () => agent.acceptVoiceResult(
          AgentResponse.fromJson({
            ...fixture.result,
            'reply': 'Conversation reply $i',
          }),
          transcript: 'Question $i',
        ),
      );
    }
    await tester.pump(const Duration(milliseconds: 400));
    final before = tester.getTopLeft(selector);
    await tester.drag(find.byType(ListView), const Offset(0, 350));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getTopLeft(selector), before);
    expect(selector.hitTestable(), findsOneWidget);
  });
}
