import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sehatmate_ai/features/agent/controllers/agent_controller.dart';
import 'package:sehatmate_ai/features/agent/screens/agent_screen.dart';
import 'package:sehatmate_ai/features/agent/services/agent_session_store.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_controller.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_scope.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_surface.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_transport.dart';
import 'package:sehatmate_ai/localization/app_language.dart';
import 'package:sehatmate_ai/localization/app_strings.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
import 'package:sehatmate_ai/services/auth_service.dart';
import 'package:sehatmate_ai/widgets/app_error_boundary.dart';
import 'voice_companion_controller_test.dart' as fixtures;

void main() {
  late VoiceCompanionController voice;
  late AgentController agent;
  late fixtures.Device device;
  late fixtures.Backend backend;
  late fixtures.Transport transport;
  late LanguageController language;
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
    agent = AgentController(client: fixtures.Client());
    device = fixtures.Device();
    backend = fixtures.Backend();
    transport = fixtures.Transport();
    language = LanguageController.forTesting();
    voice = VoiceCompanionController(
      backend: backend,
      transport: transport,
      agent: agent,
      authenticated: () => true,
      device: device,
      delay: (_) async {},
    );
  });
  tearDown(() async {
    await voice.end();
    voice.dispose();
    agent.dispose();
    language.dispose();
  });

  Future<void> pumpVoice(
    WidgetTester tester, {
    String state = 'listening',
    Size size = const Size(360, 640),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
    });
    await tester.runAsync(() => voice.start(language.language));
    voice.state = state;
    if (state == 'muted') await tester.runAsync(voice.mute);
    await tester.pumpWidget(
      LanguageScope(
        controller: language,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: Directionality(
              textDirection: language.language.textDirection,
              child: VoiceCompanionHost(controller: voice, child: child!),
            ),
          ),
          home: AgentScreen(voiceService: device),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'active voice has one Listening heading and no framework layout or overlay errors',
    (tester) async {
      await pumpVoice(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Listening'), findsOneWidget);
      expect(find.byType(VoiceCompanionSurface), findsOneWidget);
      expect(find.byType(AgentScreen), findsNothing);
      expect(find.byType(AgentScreen, skipOffstage: false), findsOneWidget);
      expect(find.text("This page didn't load"), findsNothing);
    },
  );
  testWidgets(
    'speech budget recovery explains the next step without provider details',
    (tester) async {
      await pumpVoice(tester, state: 'recovering');
      voice.recoveryCode = 'FISH_REQUEST_LIMIT';
      voice.notifyListeners();
      await tester.pump();
      expect(find.text('Voice needs attention'), findsOneWidget);
      expect(
        find.textContaining('Voice limit reached for this session.'),
        findsOneWidget,
      );
      expect(find.textContaining('FISH_'), findsNothing);
      expect(find.textContaining('Fish Audio'), findsNothing);
    },
  );

  const headings = {
    'connecting': 'Connecting...',
    'listening': 'Listening',
    'processing': 'Thinking...',
    'speaking': 'SehatMate is speaking',
    'recovering': 'Voice needs attention',
    'disconnected': 'Voice disconnected',
    'muted': 'Muted',
  };
  for (final size in [
    const Size(360, 640),
    const Size(360, 720),
    const Size(393, 873),
  ]) {
    for (final entry in headings.entries) {
      testWidgets(
        '${entry.key} fits $size with one voice surface and no layout errors',
        (tester) async {
          voice.finalTranscript = 'Hello, can you hear me?';
          voice.reply = 'Your walk is scheduled.';
          voice.recoveryCode = 'VOICE_CONNECTION_FAILED';
          await pumpVoice(tester, state: entry.key, size: size);
          expect(find.text(entry.value), findsOneWidget);
          expect(find.text('SehatMate AI'), findsOneWidget);
          expect(find.byType(VoiceCompanionSurface), findsOneWidget);
          expect(find.byType(AgentScreen), findsNothing);
          expect(find.text("This page didn't load"), findsNothing);
          expect(find.text('VOICE_CONNECTION_FAILED'), findsNothing);
          if (entry.key == 'listening') {
            expect(find.text('Speak naturally'), findsOneWidget);
          }
          if (entry.key == 'disconnected') {
            expect(find.text('Reconnect'), findsOneWidget);
          }
          if (entry.key == 'processing') {
            expect(find.text('Hello, can you hear me?'), findsOneWidget);
            final manual = tester.widget<TextButton>(
              find.widgetWithText(TextButton, 'Manual mode'),
            );
            expect(manual.onPressed, isNull);
          }
          if (entry.key == 'speaking') {
            expect(find.text('Your walk is scheduled.'), findsOneWidget);
          }
          if (entry.key == 'connecting') {
            expect(find.text('Cancel'), findsOneWidget);
          }
          for (final button
              in find
                  .byWidgetPredicate((w) => w is ButtonStyleButton)
                  .evaluate()) {
            final rect = tester.getRect(find.byWidget(button.widget));
            final buttonSize = tester.getSize(find.byWidget(button.widget));
            expect(buttonSize.height, greaterThanOrEqualTo(48));
            expect(buttonSize.width, greaterThanOrEqualTo(48));
            expect(rect.bottom, lessThanOrEqualTo(size.height - 24));
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'long exact reply scrolls while controls stay visible with large text',
    (tester) async {
      voice.reply = List.filled(
        35,
        'Keep the exact medicine, dose and timing text.',
      ).join(' ');
      await pumpVoice(tester, state: 'speaking', scale: 1.8);
      final scroll = find.descendant(
        of: find.byKey(const ValueKey('voice_content_scroll')),
        matching: find.byType(Scrollable),
      );
      expect(
        tester.state<ScrollableState>(scroll).position.maxScrollExtent,
        greaterThan(0),
      );
      expect(find.text(voice.reply), findsOneWidget);
      expect(find.text('End voice').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'transport disconnect maps to voice recovery rather than a fatal page',
    (tester) async {
      voice.recoveryCode = 'LIVEKIT_DISCONNECTED';
      await pumpVoice(tester, state: 'recovering');
      expect(find.text('Voice disconnected'), findsOneWidget);
      expect(find.text('Reconnect'), findsOneWidget);
      expect(find.text('LIVEKIT_DISCONNECTED'), findsNothing);
      expect(find.text("This page didn't load"), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final selected in [AppLanguage.urdu, AppLanguage.romanUrdu]) {
    testWidgets('$selected voice UI fits a small phone with enlarged text', (
      tester,
    ) async {
      await language.setLanguage(selected, syncToServer: false);
      await pumpVoice(tester, scale: 1.4);
      expect(
        find.text(AppStrings.get('agent_companion_listening', selected)),
        findsOneWidget,
      );
      expect(find.byType(VoiceCompanionSurface), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'listening orb accompanies long live transcript without overflow',
    (tester) async {
      voice.interimTranscript = List.filled(
        60,
        'Live recognized words',
      ).join(' ');
      await pumpVoice(tester, scale: 1.8);
      expect(find.byKey(const ValueKey('sehatmate_voice_orb')), findsOneWidget);
      expect(find.text(voice.interimTranscript), findsOneWidget);
      expect(
        find.byKey(const ValueKey('voice_transcript_surface')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final selected in [AppLanguage.urdu, AppLanguage.romanUrdu]) {
    testWidgets('$selected voice fits keyboard inset and long transcript', (
      tester,
    ) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await language.setLanguage(selected, syncToServer: false);
      voice.interimTranscript = List.filled(40, 'Recognized words').join(' ');
      await pumpVoice(tester, scale: 1.4);
      expect(find.text(voice.interimTranscript), findsOneWidget);
      final viewport = find
          .ancestor(
            of: find.byKey(const ValueKey('voice_bottom_controls')),
            matching: find.byType(SingleChildScrollView),
          )
          .first;
      expect(tester.getRect(viewport).bottom, lessThanOrEqualTo(380));
      final end = find.text(AppStrings.get('agent_voice_end', selected));
      await tester.ensureVisible(end);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getRect(end).bottom, lessThanOrEqualTo(380));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('rapid state transitions retain one Listening heading', (
    tester,
  ) async {
    await pumpVoice(tester);
    voice.state = 'processing';
    voice.notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Thinking...'), findsOneWidget);
    voice.state = 'listening';
    voice.notifyListeners();
    await tester.pump();
    expect(find.text('Listening'), findsOneWidget);
    expect(find.byType(VoiceCompanionSurface), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'manual mode returns to the preserved Agent route without another voice surface',
    (tester) async {
      await pumpVoice(tester);
      final original = tester.state(
        find.byType(AgentScreen, skipOffstage: false),
      );
      await tester.tap(find.text('Manual mode'));
      await tester.pumpAndSettle();
      expect(voice.state, 'manual');
      expect(tester.state(find.byType(AgentScreen)), same(original));
      expect(find.byType(VoiceCompanionSurface), findsNothing);
      expect(find.text('Listening'), findsNothing);
      expect(tester.takeException(), isNull);
      await voice.end();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('mute and end buttons use existing controller actions', (
    tester,
  ) async {
    await pumpVoice(tester);
    await tester.tap(find.text('Mute'));
    await tester.pump();
    expect(voice.state, 'muted');
    expect(find.text('Muted'), findsOneWidget);
    await tester.tap(find.text('End voice'));
    await tester.pumpAndSettle();
    expect(voice.voiceSessionId, isNull);
    expect(find.byType(VoiceCompanionSurface), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'end remains available while reconnect authorization is pending',
    (tester) async {
      await pumpVoice(tester);
      await tester.runAsync(() async {
        transport.connectionController.add(VoiceConnection.disconnected);
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      backend.renewal = Completer<Map<String, dynamic>>();
      await tester.tap(find.text('Reconnect'));
      await tester.pump();
      expect(backend.calls, contains('token'));
      final end = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'End voice'),
      );
      expect(end.onPressed, isNotNull);
      await tester.tap(find.text('End voice'));
      await tester.pumpAndSettle();
      backend.renewal!.complete(fixtures.binding());
      await tester.pump();
      expect(voice.state, 'idle');
      expect(voice.voiceSessionId, isNull);
      expect(find.byType(VoiceCompanionSurface), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'multiple child build failures produce one route-level fatal surface',
    (tester) async {
      final originalErrorBuilder = ErrorWidget.builder;
      final originalHandler = FlutterError.onError;
      final errors = <FlutterErrorDetails>[];
      ErrorWidget.builder = (details) => AppBuildFailure(details: details);
      FlutterError.onError = errors.add;
      addTearDown(() {
        ErrorWidget.builder = originalErrorBuilder;
        FlutterError.onError = originalHandler;
      });
      await tester.pumpWidget(
        LanguageScope(
          controller: language,
          child: MaterialApp(
            home: AppRouteErrorBoundary(
              child: Column(
                children: [
                  Builder(
                    builder: (_) => throw StateError('first failed widget'),
                  ),
                  Builder(
                    builder: (_) => throw StateError('second failed widget'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(errors.length, 2);
      expect(find.text("This page didn't load"), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
