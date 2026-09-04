import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';

import '../../../core/api_config.dart';
import '../../../services/auth_service.dart';
import '../models/agent_speech.dart';
import 'agent_service.dart';

class AgentVoiceRecording {
  const AgentVoiceRecording({
    required this.path,
    required this.duration,
    this.contentType = AgentVoiceService.recordingContentType,
  });

  final String path;
  final Duration duration;
  final String contentType;
}

class AgentVoiceTranscript {
  const AgentVoiceTranscript({required this.text});

  final String text;
}

abstract interface class AgentVoiceRecorder {
  Future<bool> hasPermission();
  Future<void> start();
  Future<AgentVoiceRecording?> stop();
  Future<void> dispose();
}

abstract interface class AgentVoiceTranscriber {
  Future<AgentVoiceTranscript> transcribe(AgentVoiceRecording recording);
}

abstract interface class AgentVoicePlayer {
  Future<void> stop();
  Future<void> play(AgentSpeech speech);
  Future<void> dispose();
}

class RecordAgentVoiceRecorder implements AgentVoiceRecorder {
  RecordAgentVoiceRecorder({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  DateTime? _startedAt;
  String? _path;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start() async {
    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}sehatmate_voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
    _path = path;
    _startedAt = DateTime.now();
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
  }

  @override
  Future<AgentVoiceRecording?> stop() async {
    final path = await _recorder.stop();
    final startedAt = _startedAt;
    _startedAt = null;
    final resolvedPath = path ?? _path;
    _path = null;
    if (resolvedPath == null || resolvedPath.trim().isEmpty) return null;
    return AgentVoiceRecording(
      path: resolvedPath,
      duration: startedAt == null
          ? Duration.zero
          : DateTime.now().difference(startedAt),
    );
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}

class AgentVoiceService implements AgentVoiceTranscriber {
  AgentVoiceService({
    http.Client? client,
    AuthSession? authSession,
    AgentAuthTokenProvider? tokenProvider,
  }) : _client = client ?? http.Client(),
       _tokenProvider =
           tokenProvider ??
           AuthSessionAgentTokenProvider(authSession ?? AuthSession.instance);

  static final instance = AgentVoiceService();
  static const recordingContentType = 'audio/mp4';
  static const maxAudioBytes = 1500000;
  static const maxDuration = Duration(seconds: 30);
  static const _timeout = Duration(seconds: 45);

  final http.Client _client;
  final AgentAuthTokenProvider _tokenProvider;

  @override
  Future<AgentVoiceTranscript> transcribe(AgentVoiceRecording recording) async {
    if (!ApiConfig.isConfigured) {
      throw const AgentException(
        'SehatMate AI is temporarily unavailable. Please try again.',
        code: AgentErrorCode.unavailable,
        retryable: true,
      );
    }

    final token = _tokenProvider.token;
    if (token == null || token.isEmpty) {
      throw const AgentException(
        'Please sign in to continue.',
        code: AgentErrorCode.unauthenticated,
      );
    }

    final file = File(recording.path);
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw const AgentException(
          'No speech was detected.',
          code: AgentErrorCode.noSpeech,
        );
      }
      if (bytes.length > maxAudioBytes || recording.duration > maxDuration) {
        throw const AgentException(
          'The voice recording is too long.',
          code: AgentErrorCode.unavailable,
        );
      }

      final response = await _client
          .post(
            ApiConfig.endpoint('/agent/voice/transcribe'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'Content-Type': recording.contentType,
              'X-SehatMate-Recording-Duration-Ms': recording
                  .duration
                  .inMilliseconds
                  .toString(),
            },
            body: bytes,
          )
          .timeout(_timeout);

      final decoded = _decode(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _exceptionFromVoiceError(response.statusCode, decoded);
      }

      final data = decoded['data'] is Map<String, dynamic>
          ? decoded['data'] as Map<String, dynamic>
          : decoded;
      final transcript = data['transcript']?.toString().trim() ?? '';
      if (transcript.isEmpty) {
        throw const AgentException(
          'No speech was detected.',
          code: AgentErrorCode.noSpeech,
        );
      }
      return AgentVoiceTranscript(text: transcript);
    } on AgentException {
      rethrow;
    } on TimeoutException {
      throw const AgentException(
        'SehatMate AI is temporarily unavailable. Please try again.',
        code: AgentErrorCode.timeout,
        retryable: true,
      );
    } on FormatException {
      throw const AgentException(
        'SehatMate AI returned an invalid response.',
        code: AgentErrorCode.malformed,
      );
    } finally {
      unawaited(file.delete().catchError((_) => file));
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('Expected a JSON object.');
  }

  AgentException _exceptionFromVoiceError(
    int statusCode,
    Map<String, dynamic> decoded,
  ) {
    final rawCode = decoded['code']?.toString().toUpperCase() ?? '';
    if (rawCode == 'VOICE_NO_SPEECH' || rawCode == 'VOICE_EMPTY_AUDIO') {
      return const AgentException(
        'No speech was detected.',
        code: AgentErrorCode.noSpeech,
      );
    }
    if (statusCode == 401) {
      return const AgentException(
        'Please sign in to continue.',
        code: AgentErrorCode.unauthenticated,
      );
    }
    if (statusCode == 429) {
      return const AgentException(
        'SehatMate AI is busy right now. Please try again shortly.',
        code: AgentErrorCode.rateLimited,
        retryable: true,
      );
    }
    return AgentException(
      'SehatMate AI is temporarily unavailable. Please try again.',
      code: statusCode >= 500
          ? AgentErrorCode.unavailable
          : AgentErrorCode.unknown,
      statusCode: statusCode,
      retryable: statusCode == 408 || statusCode == 429 || statusCode >= 500,
    );
  }
}

class AudioPlayersAgentVoicePlayer implements AgentVoicePlayer {
  AudioPlayersAgentVoicePlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> play(AgentSpeech speech) async {
    await _player.play(
      BytesSource(speech.audioBytes, mimeType: speech.contentType),
    );
  }

  @override
  Future<void> dispose() => _player.dispose();
}
