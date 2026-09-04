import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/features/agent/services/agent_service.dart';
import 'package:sehatmate_ai/features/agent/services/agent_voice_service.dart';
import 'package:sehatmate_ai/localization/app_language.dart';

class _FakeSpeechRecognizer implements AgentDeviceSpeechRecognizer {
  _FakeSpeechRecognizer({
    this.initializeResult = true,
    this.localeValues = const ['en-US', 'ur-PK'],
  });

  bool initializeResult;
  List<String> localeValues;
  AgentSpeechStatusListener? statusListener;
  AgentSpeechErrorListener? errorListener;
  AgentSpeechResultListener? resultListener;
  String? listenedLocaleId;
  Duration? listenedFor;
  Duration? pauseFor;
  int initializeCalls = 0;
  int localeCalls = 0;
  int listenCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  bool _isListening = false;

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> initialize({
    required AgentSpeechStatusListener onStatus,
    required AgentSpeechErrorListener onError,
  }) async {
    initializeCalls += 1;
    statusListener = onStatus;
    errorListener = onError;
    return initializeResult;
  }

  @override
  Future<List<String>> locales() async {
    localeCalls += 1;
    return localeValues;
  }

  @override
  Future<void> listen({
    required AgentSpeechResultListener onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
  }) async {
    listenCalls += 1;
    resultListener = onResult;
    listenedLocaleId = localeId;
    listenedFor = listenFor;
    this.pauseFor = pauseFor;
    _isListening = true;
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    _isListening = false;
  }

  @override
  Future<void> cancel() async {
    cancelCalls += 1;
    _isListening = false;
  }

  void emitResult(String text, {bool finalResult = false}) {
    resultListener?.call(text, finalResult);
  }

  void emitStatus(String status) {
    statusListener?.call(status);
  }

  void emitError({bool permanent = false}) {
    errorListener?.call(
      AgentSpeechRecognitionFailure('error', permanent: permanent),
    );
  }
}

class _FakeTextToSpeech implements AgentDeviceTextToSpeech {
  _FakeTextToSpeech({this.languageValues = const ['en-US', 'ur-PK']});

  List<String> languageValues;
  final spoken = <String>[];
  final selectedLanguages = <String>[];
  int awaitCompletionCalls = 0;
  int stopCalls = 0;
  bool failSpeak = false;

  @override
  Future<void> awaitSpeakCompletion(bool enabled) async {
    if (enabled) awaitCompletionCalls += 1;
  }

  @override
  Future<List<String>> languages() async => languageValues;

  @override
  Future<void> setLanguage(String language) async {
    selectedLanguages.add(language);
  }

  @override
  Future<void> speak(String text) async {
    if (failSpeak) throw StateError('TTS failed');
    spoken.add(text);
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }
}

void main() {
  test(
    'startListening uses device speech with best available locale',
    () async {
      final speech = _FakeSpeechRecognizer(
        localeValues: const ['en-GB', 'ur-IN'],
      );
      final service = AgentVoiceService(speechRecognizer: speech);

      await service.startListening(language: AppLanguage.romanUrdu);

      expect(speech.initializeCalls, 1);
      expect(speech.listenCalls, 1);
      expect(speech.listenedLocaleId, 'ur-IN');
      expect(speech.listenedFor, AgentVoiceService.maxListenDuration);
      expect(speech.pauseFor, AgentVoiceService.pauseForSilenceDuration);
    },
  );

  test('unavailable device speech does not start listening', () async {
    final speech = _FakeSpeechRecognizer(initializeResult: false);
    final service = AgentVoiceService(speechRecognizer: speech);

    final available = await service.initializeSpeech(AppLanguage.english);

    expect(available, isFalse);
    expect(
      () => service.startListening(language: AppLanguage.english),
      throwsA(isA<AgentException>()),
    );
    expect(speech.listenCalls, 0);
  });

  test('stopListening returns the final recognized text', () async {
    final speech = _FakeSpeechRecognizer();
    final service = AgentVoiceService(speechRecognizer: speech);

    await service.startListening(language: AppLanguage.english);
    speech.emitResult('  care plans kholo  ', finalResult: true);

    final transcript = await service.stopListening();

    expect(transcript.text, 'care plans kholo');
    expect(speech.stopCalls, 1);
  });

  test(
    'empty speech result is rejected before any Agent request exists',
    () async {
      final service = AgentVoiceService(
        speechRecognizer: _FakeSpeechRecognizer(),
      );

      await service.startListening(language: AppLanguage.english);

      try {
        await service.stopListening();
        fail('Expected AgentException.');
      } on AgentException catch (error) {
        expect(error.code, AgentErrorCode.noSpeech);
      }
    },
  );

  test('permanent recognition error maps to voice unavailable', () async {
    final speech = _FakeSpeechRecognizer();
    final service = AgentVoiceService(speechRecognizer: speech);

    await service.startListening(language: AppLanguage.english);
    speech.emitError(permanent: true);

    try {
      await service.stopListening();
      fail('Expected AgentException.');
    } on AgentException catch (error) {
      expect(error.code, AgentErrorCode.unavailable);
    }
  });

  test(
    'natural recognizer completion calls the UI completion hook once',
    () async {
      final speech = _FakeSpeechRecognizer();
      final service = AgentVoiceService(speechRecognizer: speech);
      var completions = 0;

      await service.startListening(
        language: AppLanguage.english,
        onListeningComplete: () => completions += 1,
      );
      speech.emitStatus('done');
      speech.emitStatus('notListening');

      expect(completions, 1);
    },
  );

  test('speak sends exactly the backend reply to device TTS', () async {
    final tts = _FakeTextToSpeech(languageValues: const ['en-GB', 'ur-PK']);
    final service = AgentVoiceService(
      speechRecognizer: _FakeSpeechRecognizer(),
      textToSpeech: tts,
    );

    await service.speak(
      'Aapka next task 4:00 PM par hai.',
      language: AppLanguage.romanUrdu,
    );

    expect(tts.awaitCompletionCalls, 1);
    expect(tts.selectedLanguages, ['ur-PK']);
    expect(tts.spoken, ['Aapka next task 4:00 PM par hai.']);
  });

  test(
    'TTS failure propagates without altering recognized text state',
    () async {
      final speech = _FakeSpeechRecognizer();
      final tts = _FakeTextToSpeech()..failSpeak = true;
      final service = AgentVoiceService(
        speechRecognizer: speech,
        textToSpeech: tts,
      );

      await service.startListening(language: AppLanguage.english);
      speech.emitResult('haan', finalResult: true);
      final transcript = await service.stopListening();

      expect(transcript.text, 'haan');
      expect(
        () => service.speak('Shown reply.', language: AppLanguage.english),
        throwsA(isA<StateError>()),
      );
    },
  );
}
