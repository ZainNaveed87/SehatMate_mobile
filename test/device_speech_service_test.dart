import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/services/device_speech_service.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  test('second listening session uses the current done callback', () async {
    final engine = _FakeSpeechRecognitionEngine();
    final service = DeviceSpeechService(engine: engine);
    var firstDone = 0;
    var secondDone = 0;

    final first = await service.startListening(
      localeId: 'en-US',
      onTranscript: (_) {},
      onDone: () => firstDone += 1,
    );
    final second = await service.startListening(
      localeId: 'en-US',
      onTranscript: (_) {},
      onDone: () => secondDone += 1,
    );

    expect(first.started, true);
    expect(second.started, true);
    expect(engine.initializeCount, 1);

    engine.emitStatus('done');
    engine.emitStatus('notListening');

    expect(firstDone, 0);
    expect(secondDone, 1);
  });

  test('stop clears the active callback before stale status events', () async {
    final engine = _FakeSpeechRecognitionEngine();
    final service = DeviceSpeechService(engine: engine);
    var doneCount = 0;

    await service.startListening(
      localeId: 'en-US',
      onTranscript: (_) {},
      onDone: () => doneCount += 1,
    );
    await service.stopListening();
    engine.emitStatus('done');

    expect(engine.stopCount, 1);
    expect(doneCount, 0);
  });

  test('speech errors finish the current operation only once', () async {
    final engine = _FakeSpeechRecognitionEngine();
    final service = DeviceSpeechService(engine: engine);
    var doneCount = 0;

    await service.startListening(
      localeId: 'en-US',
      onTranscript: (_) {},
      onDone: () => doneCount += 1,
    );

    engine.emitError('network');
    engine.emitError('network again');
    engine.emitStatus('done');

    expect(doneCount, 1);
  });

  test('unavailable speech recognition clears callback state', () async {
    final engine = _FakeSpeechRecognitionEngine(available: false);
    final service = DeviceSpeechService(engine: engine);
    var doneCount = 0;

    final result = await service.startListening(
      localeId: 'en-US',
      onTranscript: (_) {},
      onDone: () => doneCount += 1,
    );
    engine.emitStatus('done');

    expect(result.started, false);
    expect(doneCount, 0);
  });

  test(
    'transcripts fill caller state and listen options keep locale',
    () async {
      final engine = _FakeSpeechRecognitionEngine();
      final service = DeviceSpeechService(engine: engine);
      final transcripts = <String>[];
      var doneCount = 0;

      final result = await service.startListening(
        localeId: 'ur-PK',
        onTranscript: transcripts.add,
        onDone: () => doneCount += 1,
      );

      expect(result.started, true);
      expect(engine.lastOptions?.localeId, 'ur-PK');
      expect(engine.lastOptions?.listenMode, ListenMode.dictation);
      expect(engine.lastOptions?.partialResults, true);

      engine.emitResult('  partial words  ');
      engine.emitResult('final words', finalResult: true);
      engine.emitStatus('done');

      expect(transcripts, ['partial words', 'final words']);
      expect(doneCount, 1);
    },
  );
}

class _FakeSpeechRecognitionEngine implements SpeechRecognitionEngine {
  _FakeSpeechRecognitionEngine({this.available = true});

  final bool available;
  SpeechErrorListener? errorListener;
  SpeechStatusListener? statusListener;
  SpeechResultListener? resultListener;
  SpeechListenOptions? lastOptions;
  int initializeCount = 0;
  int listenCount = 0;
  int stopCount = 0;
  bool _listening = false;

  @override
  bool get isListening => _listening;

  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
  }) async {
    initializeCount += 1;
    errorListener = onError;
    statusListener = onStatus;
    return available;
  }

  @override
  Future<void> listen({
    SpeechResultListener? onResult,
    SpeechListenOptions? listenOptions,
  }) async {
    listenCount += 1;
    _listening = true;
    resultListener = onResult;
    lastOptions = listenOptions;
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
    _listening = false;
  }

  void emitStatus(String status) {
    statusListener?.call(status);
    if (status == 'done' || status == 'notListening') {
      _listening = false;
    }
  }

  void emitError(String message) {
    errorListener?.call(SpeechRecognitionError(message, false));
    _listening = false;
  }

  void emitResult(String words, {bool finalResult = false}) {
    resultListener?.call(
      SpeechRecognitionResult([
        SpeechRecognitionWords(
          words,
          null,
          SpeechRecognitionWords.missingConfidence,
        ),
      ], finalResult ? ResultType.finalResult.value : ResultType.partial.value),
    );
    if (finalResult) {
      _listening = false;
    }
  }
}
