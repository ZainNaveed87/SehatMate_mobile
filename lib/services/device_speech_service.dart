import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class DeviceSpeechStartResult {
  const DeviceSpeechStartResult({required this.started, this.message = ''});

  final bool started;
  final String message;
}

abstract class DeviceSpeechInput {
  bool get isListening;

  Future<DeviceSpeechStartResult> startListening({
    required String localeId,
    required ValueChanged<String> onTranscript,
    required VoidCallback onDone,
  });

  Future<void> stopListening();
}

@visibleForTesting
abstract class SpeechRecognitionEngine {
  bool get isListening;

  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
  });

  Future<void> listen({
    SpeechResultListener? onResult,
    SpeechListenOptions? listenOptions,
  });

  Future<void> stop();
}

class SpeechToTextEngine implements SpeechRecognitionEngine {
  SpeechToTextEngine(this._speech);

  final SpeechToText _speech;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
  }) => _speech.initialize(onError: onError, onStatus: onStatus);

  @override
  Future<void> listen({
    SpeechResultListener? onResult,
    SpeechListenOptions? listenOptions,
  }) async {
    await _speech.listen(onResult: onResult, listenOptions: listenOptions);
  }

  @override
  Future<void> stop() => _speech.stop();
}

class DeviceSpeechService implements DeviceSpeechInput {
  DeviceSpeechService({
    SpeechToText? speech,
    @visibleForTesting SpeechRecognitionEngine? engine,
  }) : _engine = engine ?? SpeechToTextEngine(speech ?? SpeechToText());

  static final DeviceSpeechService instance = DeviceSpeechService();

  final SpeechRecognitionEngine _engine;
  bool _initialized = false;
  bool _available = false;
  bool _operationActive = false;
  bool _doneDelivered = false;
  String _lastError = '';
  VoidCallback? _activeOnDone;

  @override
  bool get isListening => _engine.isListening;

  void _setCurrentOperation(VoidCallback onDone) {
    _activeOnDone = onDone;
    _operationActive = true;
    _doneDelivered = false;
  }

  void _clearCurrentOperation() {
    _activeOnDone = null;
    _operationActive = false;
    _doneDelivered = false;
  }

  void _finishCurrentOperation() {
    if (!_operationActive || _doneDelivered) return;
    final done = _activeOnDone;
    _doneDelivered = true;
    _operationActive = false;
    _activeOnDone = null;
    done?.call();
  }

  @override
  Future<DeviceSpeechStartResult> startListening({
    required String localeId,
    required ValueChanged<String> onTranscript,
    required VoidCallback onDone,
  }) async {
    _lastError = '';
    _setCurrentOperation(onDone);
    try {
      if (!_initialized) {
        _available = await _engine.initialize(
          onStatus: (status) {
            if (status == 'done' || status == 'notListening') {
              _finishCurrentOperation();
            }
          },
          onError: (SpeechRecognitionError error) {
            _lastError = error.errorMsg;
            _finishCurrentOperation();
          },
        );
        _initialized = true;
      }

      if (!_available) {
        _clearCurrentOperation();
        return const DeviceSpeechStartResult(
          started: false,
          message:
              'Speech recognition is not available. You can still type your answer.',
        );
      }

      await _engine.listen(
        onResult: (SpeechRecognitionResult result) {
          final words = result.recognizedWords.trim();
          if (words.isNotEmpty) {
            onTranscript(words);
          }
          if (result.finalResult) {
            _finishCurrentOperation();
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenMode: ListenMode.dictation,
          partialResults: true,
        ),
      );

      if (_lastError.isNotEmpty) {
        _clearCurrentOperation();
        return DeviceSpeechStartResult(
          started: false,
          message:
              'Speech recognition could not start. You can still type your answer.',
        );
      }

      return const DeviceSpeechStartResult(started: true);
    } catch (_) {
      _clearCurrentOperation();
      return DeviceSpeechStartResult(
        started: false,
        message:
            'Speech recognition could not start. You can still type your answer.',
      );
    }
  }

  @override
  Future<void> stopListening() async {
    _clearCurrentOperation();
    if (_initialized && _available) {
      await _engine.stop();
    }
  }
}
