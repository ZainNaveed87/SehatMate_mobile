import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sehatmate_ai/localization/app_language.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/services/auth_service.dart';
import 'package:sehatmate_ai/features/agent/controllers/agent_controller.dart';
import 'package:sehatmate_ai/features/agent/models/agent_response.dart';
import 'package:sehatmate_ai/features/agent/services/agent_session_store.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_controller.dart';
import 'voice_companion_controller_test.dart' as fixture;

class ProfileSync implements ProfileLanguageSync {
  PatientProfile profile = const PatientProfile(
    usingFor: 'Myself',
    patientName: 'Test',
    ageGroup: '30 - 40',
    city: 'Test',
    preferredLanguage: 'English',
    accessibilityMode: 'Standard',
    caregiverSupport: false,
    onboardingCompleted: true,
  );
  Completer<void>? firstUpdate;
  bool fail = false;
  int updates = 0;
  @override
  bool get canSyncProfileLanguage => true;
  @override
  PatientProfile get currentProfile => profile;
  @override
  Future<PatientProfile?> fetchProfile() async => profile;
  @override
  Future<PatientProfile> updateProfile(PatientProfile value) async {
    updates++;
    if (updates == 1) await firstUpdate?.future;
    if (fail) throw StateError('profile unavailable');
    return profile = value;
  }
}

Future<void> tick() => Future<void>.delayed(Duration.zero);

class LanguageBackend extends fixture.Backend {
  LanguageBackend(this.sync);
  final ProfileSync sync;
  final preferencesAtCreate = <String>[];
  @override
  Future<Map<String, dynamic>> create(String agentSessionId) async {
    preferencesAtCreate.add(sync.profile.preferredLanguage);
    final value = await super.create(agentSessionId);
    return {...value, 'id': 'voice-${preferencesAtCreate.length}'};
  }
}

Future<
  ({
    ProfileSync sync,
    LanguageController languages,
    LanguageBackend backend,
    fixture.Transport transport,
    AgentController agent,
    VoiceCompanionController voice,
  })
>
harness() async {
  SharedPreferences.setMockInitialValues({AgentSessionStore.key: '41'});
  final sync = ProfileSync();
  final languages = LanguageController.forTesting(profileSync: sync);
  await languages.initialize();
  final backend = LanguageBackend(sync);
  final transport = fixture.Transport();
  final agent = AgentController(client: fixture.Client());
  final voice = VoiceCompanionController(
    backend: backend,
    transport: transport,
    agent: agent,
    authenticated: () => true,
    languagePreferences: languages,
  );
  addTearDown(() async {
    await voice.end();
    voice.dispose();
    agent.dispose();
    languages.dispose();
  });
  return (
    sync: sync,
    languages: languages,
    backend: backend,
    transport: transport,
    agent: agent,
    voice: voice,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('rapid preference changes persist in selection order', () async {
    final sync = ProfileSync();
    final languages = LanguageController.forTesting(profileSync: sync);
    await languages.initialize();
    sync.firstUpdate = Completer<void>();
    final urdu = languages.setLanguage(AppLanguage.urdu);
    await tick();
    final roman = languages.setLanguage(AppLanguage.romanUrdu);
    await tick();
    sync.firstUpdate!.complete();
    await Future.wait([urdu, roman]);
    expect(sync.profile.preferredLanguage, 'Roman Urdu');
    expect(languages.language, AppLanguage.romanUrdu);
    languages.dispose();
  });

  test('voice startup waits for authenticated profile persistence', () async {
    final h = await harness();
    h.sync.firstUpdate = Completer<void>();
    final selecting = h.languages.setLanguage(AppLanguage.urdu);
    await tick();
    final starting = h.voice.start(AppLanguage.urdu);
    await tick();
    expect(h.backend.preferencesAtCreate, isEmpty);
    h.sync.firstUpdate!.complete();
    await selecting;
    await starting;
    expect(h.backend.preferencesAtCreate, ['Urdu']);
    expect(h.voice.language, AppLanguage.urdu);
  });

  test(
    'active language switch recreates transport and retains Agent session/history',
    () async {
      final h = await harness();
      await h.voice.start(AppLanguage.english);
      await h.agent.acceptVoiceResult(
        AgentResponse.fromJson(fixture.result),
        transcript: 'Previous message',
      );
      final history = h.agent.messages.map((m) => m.text).toList();
      await h.languages.setLanguage(AppLanguage.urdu);
      await h.voice.languageChangeComplete;
      expect(h.backend.calls, ['create:41', 'end', 'create:41']);
      expect(h.backend.preferencesAtCreate, ['English', 'Urdu']);
      expect(h.transport.connects, 2);
      expect(h.voice.voiceSessionId, 'voice-2');
      expect(h.agent.sessionId, '41');
      expect(h.agent.messages.map((m) => m.text), history);
      expect(h.voice.state, 'listening');
      expect(h.voice.language, AppLanguage.urdu);
    },
  );

  test('manual mute survives Urdu/Roman Urdu/English rebinding', () async {
    final h = await harness();
    await h.voice.start(AppLanguage.english);
    await h.voice.mute();
    for (final language in [
      AppLanguage.urdu,
      AppLanguage.romanUrdu,
      AppLanguage.english,
    ]) {
      await h.languages.setLanguage(language);
      await h.voice.languageChangeComplete;
      expect(h.voice.language, language);
      expect(h.voice.muted, true);
      expect(h.voice.state, 'muted');
      expect(h.transport.mic, false);
    }
    expect(h.backend.preferencesAtCreate, [
      'English',
      'Urdu',
      'Roman Urdu',
      'English',
    ]);
  });

  test(
    'rapid active changes rebind only to the latest persisted preference',
    () async {
      final h = await harness();
      await h.voice.start(AppLanguage.english);
      h.sync.firstUpdate = Completer<void>();
      final urdu = h.languages.setLanguage(AppLanguage.urdu);
      await tick();
      final roman = h.languages.setLanguage(AppLanguage.romanUrdu);
      await tick();
      h.sync.firstUpdate!.complete();
      await Future.wait([urdu, roman]);
      await h.voice.languageChangeComplete;
      expect(h.backend.preferencesAtCreate, ['English', 'Roman Urdu']);
      expect(h.voice.language, AppLanguage.romanUrdu);
      expect(h.voice.enabled, true);
    },
  );

  test(
    'failed profile sync cannot recreate a stale-language voice session',
    () async {
      final h = await harness();
      await h.voice.start(AppLanguage.english);
      h.sync.fail = true;
      await h.languages.setLanguage(AppLanguage.urdu);
      await h.voice.languageChangeComplete;
      expect(h.backend.preferencesAtCreate, ['English']);
      expect(h.voice.enabled, false);
      expect(h.voice.recoveryCode, 'VOICE_LANGUAGE_SYNC_FAILED');
      expect(h.transport.mic, false);
    },
  );

  test('explicit end cancels pending automatic language rebind', () async {
    final h = await harness();
    await h.voice.start(AppLanguage.english);
    h.sync.firstUpdate = Completer<void>();
    final selecting = h.languages.setLanguage(AppLanguage.urdu);
    await tick();
    await h.voice.end();
    h.sync.firstUpdate!.complete();
    await selecting;
    await h.voice.languageChangeComplete;
    expect(h.backend.preferencesAtCreate, ['English']);
    expect(h.voice.state, 'idle');
    expect(h.transport.mic, false);
  });

  test('idle language change waits for explicit start', () async {
    final h = await harness();
    await h.languages.setLanguage(AppLanguage.urdu);
    await h.voice.languageChangeComplete;
    expect(h.backend.calls, isEmpty);
    await h.voice.start(AppLanguage.urdu);
    expect(h.backend.preferencesAtCreate, ['Urdu']);
  });

  test(
    'Roman Urdu voice displays the original Urdu-script Worker transcript',
    () async {
      final h = await harness();
      await h.languages.setLanguage(AppLanguage.romanUrdu);
      await h.voice.start(AppLanguage.romanUrdu);
      const transcript = 'میں آج بہتر محسوس کر رہا ہوں';
      h.transport.event('transcript_interim', 1, payload: {'text': transcript});
      await tick();
      expect(h.voice.interimTranscript, transcript);
      h.transport.event(
        'transcript_final',
        2,
        turnId: 'turn-test',
        payload: {'text': transcript},
      );
      await tick();
      expect(h.voice.finalTranscript, transcript);
    },
  );
  test(
    'background cancels language rebind without microphone restart',
    () async {
      final h = await harness();
      await h.voice.start(AppLanguage.english);
      h.sync.firstUpdate = Completer<void>();
      final selecting = h.languages.setLanguage(AppLanguage.urdu);
      await tick();
      await h.voice.background();
      h.sync.firstUpdate!.complete();
      await selecting;
      await h.voice.languageChangeComplete;
      expect(h.voice.enabled, false);
      expect(h.backend.preferencesAtCreate, ['English']);
      expect(h.transport.mic, false);
    },
  );
  test(
    'language change during create fences the old connection before rebinding',
    () async {
      final h = await harness();
      h.backend.creation = Completer<Map<String, dynamic>>();
      final starting = h.voice.start(AppLanguage.english);
      await tick();
      final selecting = h.languages.setLanguage(AppLanguage.urdu);
      await tick();
      h.backend.creation!.complete(fixture.binding());
      await starting;
      await selecting;
      await h.voice.languageChangeComplete;
      expect(h.backend.preferencesAtCreate, ['English', 'Urdu']);
      expect(h.transport.connects, 1);
      expect(h.voice.voiceSessionId, 'voice-2');
      expect(h.voice.language, AppLanguage.urdu);
    },
  );
  test(
    'language change in manual mode ends stale transport without starting a microphone',
    () async {
      final h = await harness();
      await h.voice.start(AppLanguage.english);
      await h.voice.manual();
      await h.languages.setLanguage(AppLanguage.urdu);
      await h.voice.languageChangeComplete;
      expect(h.voice.state, 'manual');
      expect(h.voice.voiceSessionId, isNull);
      expect(h.backend.preferencesAtCreate, ['English']);
      expect(h.transport.mic, false);
      expect(h.agent.sessionId, '41');
    },
  );
  test(
    'late old-language Worker packets cannot change the rebound session',
    () async {
      final h = await harness();
      await h.voice.start(AppLanguage.english);
      await h.voice.mute();
      await h.languages.setLanguage(AppLanguage.urdu);
      await h.voice.languageChangeComplete;
      h.transport.event('ready', 1);
      h.transport.event(
        'transcript_final',
        2,
        turnId: 'old-turn',
        payload: {'text': 'old transcript'},
      );
      await tick();
      expect(h.voice.state, 'muted');
      expect(h.voice.finalTranscript, isEmpty);
      expect(h.transport.mic, false);
      expect(h.voice.voiceSessionId, 'voice-2');
    },
  );
}
