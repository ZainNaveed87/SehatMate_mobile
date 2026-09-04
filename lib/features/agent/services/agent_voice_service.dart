import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../localization/app_language.dart';
import 'agent_service.dart';

class AgentVoiceTranscript {
  const AgentVoiceTranscript({required this.text});

  final String text;
}

class AgentSpeechRecognitionFailure {
  const AgentSpeechRecognitionFailure(this.message, {required this.permanent});

  final String message;
  final bool permanent;
}

typedef AgentSpeechResultListener =
    void Function(String recognizedWords, bool finalResult);
typedef AgentSpeechStatusListener = void Function(String status);
typedef AgentSpeechErrorListener =
    void Function(AgentSpeechRecognitionFailure error);

abstract interface class AgentDeviceSpeechRecognizer {
  bool get isListening;

  Future<bool> initialize({
    required AgentSpeechStatusListener onStatus,
    required AgentSpeechErrorListener onError,
  });
  Future<List<String>> locales();
  Future<void> listen({
    required AgentSpeechResultListener onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
  });
  Future<void> stop();
  Future<void> cancel();
}

abstract interface class AgentDeviceTextToSpeech {
  Future<void> awaitSpeakCompletion(bool enabled);
  Future<List<String>> languages();
  Future<void> setLanguage(String language);
  Future<void> speak(String text);
  Future<void> stop();
}

abstract interface class AgentVoiceClient {
  bool get speechAvailable;
  bool get isListening;

  Future<bool> initializeSpeech(AppLanguage language);
  Future<void> startListening({
    required AppLanguage language,
    VoidCallback? onListeningComplete,
  });
  Future<AgentVoiceTranscript> stopListening();
  Future<void> cancelListening();
  Future<void> speak(String text, {required AppLanguage language});
  Future<void> stopSpeaking();
  Future<void> dispose();
}

class AgentVoiceService implements AgentVoiceClient {
  AgentVoiceService({
    AgentDeviceSpeechRecognizer? speechRecognizer,
    AgentDeviceTextToSpeech? textToSpeech,
  }) : _speech = speechRecognizer ?? SpeechToTextAgentDeviceSpeechRecognizer(),
       _tts = textToSpeech;

  static final instance = AgentVoiceService();

  static const maxListenDuration = Duration(seconds: 30);
  static const pauseForSilenceDuration = Duration(seconds: 3);

  final AgentDeviceSpeechRecognizer _speech;
  AgentDeviceTextToSpeech? _tts;

  AgentDeviceTextToSpeech get _textToSpeech =>
      _tts ??= FlutterTtsAgentDeviceTextToSpeech();

  bool _speechInitialized = false;
  bool _speechAvailable = false;
  bool _ttsInitialized = false;
  bool _isListening = false;
  String _latestTranscript = '';
  AgentSpeechRecognitionFailure? _lastSpeechError;
  VoidCallback? _onListeningComplete;

  @override
  bool get speechAvailable => _speechAvailable;

  @override
  bool get isListening => _isListening || _speech.isListening;

  @override
  Future<bool> initializeSpeech(AppLanguage language) async {
    if (_speechInitialized) return _speechAvailable;

    try {
      _speechAvailable = await _speech.initialize(
        onStatus: _handleSpeechStatus,
        onError: _handleSpeechError,
      );
      _speechInitialized = true;
      if (_speechAvailable) {
        await _speechLocaleFor(language);
      }
      return _speechAvailable;
    } catch (_) {
      _speechInitialized = true;
      _speechAvailable = false;
      return false;
    }
  }

  @override
  Future<void> startListening({
    required AppLanguage language,
    VoidCallback? onListeningComplete,
  }) async {
    final available = await initializeSpeech(language);
    if (!available) {
      throw const AgentException(
        'Device speech recognition is unavailable.',
        code: AgentErrorCode.unavailable,
      );
    }

    _latestTranscript = '';
    _lastSpeechError = null;
    _onListeningComplete = onListeningComplete;
    final localeId = await _speechLocaleFor(language);

    try {
      _isListening = true;
      await _speech.listen(
        onResult: _handleSpeechResult,
        listenFor: maxListenDuration,
        pauseFor: pauseForSilenceDuration,
        localeId: localeId,
      );
    } catch (_) {
      _isListening = false;
      _onListeningComplete = null;
      throw const AgentException(
        'Device speech recognition is unavailable.',
        code: AgentErrorCode.unavailable,
      );
    }
  }

  @override
  Future<AgentVoiceTranscript> stopListening() async {
    if (_speech.isListening || _isListening) {
      await _speech.stop();
    }
    _isListening = false;
    _onListeningComplete = null;

    final transcript = _latestTranscript.trim();
    if (transcript.isEmpty) {
      final error = _lastSpeechError;
      if (error != null && error.permanent) {
        throw const AgentException(
          'Device speech recognition is unavailable.',
          code: AgentErrorCode.unavailable,
        );
      }
      throw const AgentException(
        'No speech was detected.',
        code: AgentErrorCode.noSpeech,
      );
    }

    return AgentVoiceTranscript(text: transcript);
  }

  @override
  Future<void> cancelListening() async {
    if (_speech.isListening || _isListening) {
      await _speech.cancel();
    }
    _isListening = false;
    _onListeningComplete = null;
    _latestTranscript = '';
  }

  @override
  Future<void> speak(String text, {required AppLanguage language}) async {
    final speechText = text.trim();
    if (speechText.isEmpty) return;

    await _initializeTts();
    final locale = await _ttsLocaleFor(language);
    if (locale != null && locale.trim().isNotEmpty) {
      await _textToSpeech.setLanguage(locale);
    }
    await _textToSpeech.speak(speechText);
  }

  @override
  Future<void> stopSpeaking() async {
    final tts = _tts;
    if (tts != null) {
      await tts.stop();
    }
  }

  @override
  Future<void> dispose() async {
    await cancelListening();
    await stopSpeaking();
  }

  void _handleSpeechResult(String recognizedWords, bool finalResult) {
    final text = recognizedWords.trim();
    if (text.isNotEmpty) _latestTranscript = text;
  }

  void _handleSpeechError(AgentSpeechRecognitionFailure error) {
    _lastSpeechError = error;
    _isListening = false;
    _notifyListeningComplete();
  }

  void _handleSpeechStatus(String status) {
    final normalized = status.toLowerCase().trim();
    if (normalized == 'done' || normalized == 'notlistening') {
      _isListening = false;
      _notifyListeningComplete();
    }
  }

  void _notifyListeningComplete() {
    final callback = _onListeningComplete;
    if (callback == null) return;
    _onListeningComplete = null;
    callback();
  }

  Future<String?> _speechLocaleFor(AppLanguage language) async {
    try {
      final locales = await _speech.locales();
      return _bestLocale(
        locales,
        preferred: language.speechRecognitionLocale,
        languageCode: language == AppLanguage.english ? 'en' : 'ur',
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _ttsLocaleFor(AppLanguage language) async {
    try {
      final languages = await _textToSpeech.languages();
      return _bestLocale(
        languages,
        preferred: language.ttsLocale,
        languageCode: language == AppLanguage.english ? 'en' : 'ur',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _initializeTts() async {
    if (_ttsInitialized) return;
    await _textToSpeech.awaitSpeakCompletion(true);
    _ttsInitialized = true;
  }

  String? _bestLocale(
    Iterable<String> available, {
    required String preferred,
    required String languageCode,
  }) {
    final normalizedPreferred = _normalizeLocale(preferred);
    final candidates = available
        .map((locale) => locale.trim())
        .where((locale) => locale.isNotEmpty)
        .toList(growable: false);

    for (final candidate in candidates) {
      if (_normalizeLocale(candidate) == normalizedPreferred) return candidate;
    }

    final languagePrefix = '${languageCode.toLowerCase()}_';
    for (final candidate in candidates) {
      final normalized = _normalizeLocale(candidate);
      if (normalized == languageCode.toLowerCase() ||
          normalized.startsWith(languagePrefix)) {
        return candidate;
      }
    }

    return null;
  }

  String _normalizeLocale(String locale) =>
      locale.trim().replaceAll('-', '_').toLowerCase();
}

class SpeechToTextAgentDeviceSpeechRecognizer
    implements AgentDeviceSpeechRecognizer {
  SpeechToTextAgentDeviceSpeechRecognizer({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> initialize({
    required AgentSpeechStatusListener onStatus,
    required AgentSpeechErrorListener onError,
  }) {
    return _speech.initialize(
      onStatus: onStatus,
      onError: (error) => onError(
        AgentSpeechRecognitionFailure(
          error.errorMsg,
          permanent: error.permanent,
        ),
      ),
    );
  }

  @override
  Future<List<String>> locales() async {
    final locales = await _speech.locales();
    return locales.map((locale) => locale.localeId).toList(growable: false);
  }

  @override
  Future<void> listen({
    required AgentSpeechResultListener onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
  }) {
    return _speech.listen(
      onResult: (result) =>
          onResult(result.recognizedWords, result.finalResult),
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
        listenMode: ListenMode.confirmation,
        listenFor: listenFor,
        pauseFor: pauseFor,
        localeId: localeId,
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();
}

class FlutterTtsAgentDeviceTextToSpeech implements AgentDeviceTextToSpeech {
  FlutterTtsAgentDeviceTextToSpeech({FlutterTts? tts})
    : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  @override
  Future<void> awaitSpeakCompletion(bool enabled) =>
      _tts.awaitSpeakCompletion(enabled);

  @override
  Future<List<String>> languages() async {
    final languages = await _tts.getLanguages;
    return languages
        .map((language) => language.toString())
        .where((language) => language.trim().isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> setLanguage(String language) => _tts.setLanguage(language);

  @override
  Future<void> speak(String text) => _tts.speak(text);

  @override
  Future<void> stop() => _tts.stop();
}
