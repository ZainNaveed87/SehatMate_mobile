import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sehatmate_ai/features/agent/controllers/agent_controller.dart';
import 'package:sehatmate_ai/features/agent/services/agent_session_store.dart';
import 'package:sehatmate_ai/features/agent/models/agent_transcript_presentation.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_controller.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_surface.dart';
import 'package:sehatmate_ai/localization/app_language.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
import 'voice_companion_controller_test.dart' as fixtures;

void main() {
  test(
    'unsafe display rendering is rejected without exposing raw Urdu in Roman mode',
    () {
      const raw = 'میں Panadol 500 mg صبح 08:30 لیتا ہوں';
      expect(
        validatedRomanTranscript(
          raw,
          'Main Panadol 500 mg subah 08:30 leta hoon',
        ),
        'Main Panadol 500 mg subah 08:30 leta hoon',
      );
      for (final candidate in [
        'Main Panadol 50 mg subah 08:30 leta hoon',
        'Main OtherDrug 500 mg subah 08:30 leta hoon',
        raw,
      ]) {
        expect(validatedRomanTranscript(raw, candidate), isNull);
        expect(
          transcriptForDisplay(
            raw,
            AppLanguage.romanUrdu,
            rendering: candidate,
            complete: true,
          ),
          'Roman Urdu matn dastiyab nahi. Asal paigham mehfooz hai.',
        );
      }
    },
  );
  testWidgets(
    'Roman Urdu voice surface does not expose raw Urdu-script ASR as the visible transcript',
    (tester) async {
      SharedPreferences.setMockInitialValues({AgentSessionStore.key: '41'});
      final agent = AgentController(client: fixtures.Client()),
          transport = fixtures.Transport();
      final language = LanguageController.forTesting();
      await tester.runAsync(() => language.setLanguage(AppLanguage.romanUrdu));
      final voice = VoiceCompanionController(
        backend: fixtures.Backend(),
        transport: transport,
        agent: agent,
        authenticated: () => true,
      );
      await voice.start(AppLanguage.romanUrdu);
      transport.event(
        'transcript_final',
        1,
        turnId: 't1',
        payload: {'text': 'کیئر پلان بنانے میں مدد کرو'},
      );
      transport.event('processing', 2, turnId: 't1');
      await tester.pump();
      await tester.pumpWidget(
        LanguageScope(
          controller: language,
          child: MaterialApp(home: VoiceCompanionSurface(controller: voice)),
        ),
      );
      expect(find.text('کیئر پلان بنانے میں مدد کرو'), findsNothing);
      expect(
        find.text('Awaz ka paigham mil gaya. Roman Urdu matn ka intezar hai.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await voice.end();
      voice.dispose();
      agent.dispose();
      language.dispose();
    },
  );
  for (final language in AppLanguage.values) {
    test(
      'voice presentation respects $language without rewriting raw ASR',
      () async {
        SharedPreferences.setMockInitialValues({AgentSessionStore.key: '41'});
        final agent = AgentController(client: fixtures.Client());
        final backend = fixtures.Backend(), transport = fixtures.Transport();
        final voice = VoiceCompanionController(
          backend: backend,
          transport: transport,
          agent: agent,
          authenticated: () => true,
        );
        await voice.start(language);
        const raw = 'کیئر پلان بنانے میں مدد کرو';
        const roman = 'Care plan banane mein madad karo';
        transport.event(
          'transcript_final',
          1,
          turnId: 't1',
          payload: {'text': raw},
        );
        await Future<void>.delayed(Duration.zero);
        expect(voice.finalTranscript, raw);
        if (language == AppLanguage.romanUrdu) {
          expect(voice.visibleFinalTranscript, isNot(contains('کیئر')));
        } else {
          expect(voice.visibleFinalTranscript, raw);
        }
        transport.event(
          'agent_result',
          2,
          turnId: 't1',
          payload: {
            'result': {
              ...fixtures.result,
              'language': language.agentLanguageCode,
              'reply': 'Care plan ka naam kya rakhoon?',
              'displayTranscript': roman,
            },
          },
        );
        await Future<void>.delayed(Duration.zero);
        final user = agent.messages.first;
        expect(user.text, raw);
        expect(
          user.displayText,
          language == AppLanguage.romanUrdu ? roman : raw,
        );
        expect(
          voice.visibleFinalTranscript,
          language == AppLanguage.romanUrdu ? roman : raw,
        );
        await voice.end();
        voice.dispose();
        agent.dispose();
      },
    );
  }
  test(
    'stale results cannot replace a newer transcript presentation',
    () async {
      SharedPreferences.setMockInitialValues({AgentSessionStore.key: '41'});
      final agent = AgentController(client: fixtures.Client()),
          transport = fixtures.Transport();
      final voice = VoiceCompanionController(
        backend: fixtures.Backend(),
        transport: transport,
        agent: agent,
        authenticated: () => true,
      );
      await voice.start(AppLanguage.romanUrdu);
      transport.event(
        'transcript_final',
        1,
        turnId: 'old',
        payload: {'text': 'پرانا پیغام'},
      );
      transport.event(
        'transcript_final',
        2,
        turnId: 'new',
        payload: {'text': 'نیا پیغام'},
      );
      transport.event(
        'agent_result',
        3,
        turnId: 'old',
        payload: {
          'result': {
            ...fixtures.result,
            'language': 'roman_ur',
            'displayTranscript': 'Purana paigham',
          },
        },
      );
      await Future<void>.delayed(Duration.zero);
      expect(voice.finalTranscript, 'نیا پیغام');
      expect(voice.visibleFinalTranscript, isNot('Purana paigham'));
      await voice.end();
      voice.dispose();
      agent.dispose();
    },
  );
}
