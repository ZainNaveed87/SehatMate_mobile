import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sehatmate_ai/features/agent/controllers/agent_controller.dart';
import 'package:sehatmate_ai/features/agent/models/agent_request.dart';
import 'package:sehatmate_ai/features/agent/models/agent_response.dart';
import 'package:sehatmate_ai/features/agent/services/agent_session_store.dart';
import 'package:sehatmate_ai/features/agent/services/agent_voice_service.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_controller.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_backend.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_transport.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_scope.dart';
import 'package:sehatmate_ai/features/agent/navigation/agent_navigation_handler.dart';
import 'package:sehatmate_ai/features/agent/models/agent_navigation.dart';
import 'package:sehatmate_ai/localization/app_language.dart';

class Client implements AgentClient {
  @override
  Future<AgentResponse> send(AgentRequest request) async =>
      AgentResponse.fromJson(result);
}

final result = <String, dynamic>{
  'success': true,
  'sessionId': '41',
  'language': 'en',
  'reply': 'Your walk is scheduled.',
  'referencedEntities': [],
};
Map<String, dynamic> binding([int epoch = 1, String owner = 'worker']) => {
  'id': 'voice-1',
  'agentSessionId': '41',
  'epoch': epoch,
  'transportOwner': owner,
  'status': 'active',
  'participantIdentity': 'user-1',
  'workerIdentity': 'agent-job',
  'roomName': 'room-1',
  'livekitUrl': 'wss://test.invalid',
  'token': 'room-token',
  'expiresAt': DateTime.now()
      .add(const Duration(minutes: 10))
      .toIso8601String(),
};

class Backend implements VoiceBackend {
  final calls = <String>[];
  Completer<Map<String, dynamic>>? creation;
  Completer<Map<String, dynamic>>? renewal;
  bool uncertain = false;
  String receiptStatus = 'completed';
  String? activeTurn;
  String? canonicalTurn;
  Map<String, dynamic> replyResult = result;
  @override
  Future<Map<String, dynamic>> create(String agentSessionId) async {
    calls.add('create:$agentSessionId');
    return creation?.future ?? binding();
  }

  @override
  Future<Map<String, dynamic>> token(String id) async {
    calls.add('token');
    return renewal?.future ?? binding(currentEpoch);
  }

  int currentEpoch = 1;
  String currentOwner = 'worker';
  @override
  Future<Map<String, dynamic>> get(String id) async => {
    ...binding(currentEpoch, currentOwner),
    'activeTurnId': activeTurn,
  };
  @override
  Future<Map<String, dynamic>> transfer(
    String id,
    int epoch,
    String mode,
  ) async {
    calls.add('transfer:$mode');
    currentEpoch = epoch + 1;
    currentOwner = mode;
    return binding(epoch + 1, mode);
  }

  @override
  Future<Map<String, dynamic>> submit(
    String id,
    Map<String, dynamic> body,
  ) async {
    calls.add('submit');
    if (uncertain) throw TimeoutException('uncertain');
    return {
      'status': 'completed',
      'epoch': body['epoch'],
      'turnId': canonicalTurn ?? body['turnId'],
      'result': replyResult,
    };
  }

  @override
  Future<Map<String, dynamic>> receipt(String id, String turnId) async {
    calls.add('receipt');
    return {
      'status': receiptStatus,
      'epoch': 1,
      'turnId': turnId,
      'result': result,
    };
  }

  @override
  Future<void> end(String id) async {
    calls.add('end');
  }
}

class Transport implements VoiceTransport {
  final eventsController = StreamController<VoicePacket>.broadcast(sync: true);
  final connectionController = StreamController<VoiceConnection>.broadcast(
    sync: true,
  );
  final controls = <Map<String, dynamic>>[];
  String? worker;
  bool mic = false;
  final microphoneChanges = <bool>[];
  int connects = 0;
  @override
  Stream<VoicePacket> get events => eventsController.stream;
  @override
  Stream<VoiceConnection> get connections => connectionController.stream;
  @override
  Future<void> connect(Map<String, dynamic> session) async {
    connects++;
  }

  @override
  Future<void> bindWorker(String identity) async {
    worker = identity;
  }

  @override
  Future<void> microphone(bool enabled) async {
    microphoneChanges.add(enabled);
    mic = enabled;
  }

  @override
  Future<void> send(Map<String, dynamic> value) async {
    controls.add(value);
  }

  @override
  Future<void> disconnect() async {
    mic = false;
  }

  void event(
    String kind,
    int seq, {
    int epoch = 1,
    String sender = 'agent-job',
    String? turnId,
    Map<String, dynamic> payload = const {},
  }) => eventsController.add(
    VoicePacket(sender, 'sehatmate.voice.v1', {
      'v': 1,
      'type': kind,
      'seq': seq,
      'epoch': epoch,
      'voiceSessionId': 'voice-1',
      if (turnId != null) 'turnId': turnId,
      ...payload,
    }),
  );
}

class Device implements AgentVoiceClient {
  final spoken = <String>[];
  final languages = <AppLanguage>[];
  Completer<void>? speaking;
  VoidCallback? completed;
  String finalText = '';
  @override
  bool speechAvailable = true;
  @override
  bool isListening = false;
  @override
  Future<bool> initializeSpeech(AppLanguage language) async => true;
  @override
  Future<void> startListening({
    required AppLanguage language,
    VoidCallback? onListeningComplete,
  }) async {
    isListening = true;
    completed = onListeningComplete;
  }

  @override
  Future<AgentVoiceTranscript> stopListening() async {
    isListening = false;
    return AgentVoiceTranscript(text: finalText);
  }

  @override
  Future<void> cancelListening() async {
    isListening = false;
  }

  @override
  Future<void> speak(String text, {required AppLanguage language}) async {
    spoken.add(text);
    languages.add(language);
    await speaking?.future;
  }

  @override
  Future<void> stopSpeaking() async {
    if (speaking != null && !speaking!.isCompleted) speaking!.complete();
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  late Backend backend;
  late Transport transport;
  late AgentController agent;
  late VoiceCompanionController voice;
  late Device device;
  setUp(() async {
    SharedPreferences.setMockInitialValues({AgentSessionStore.key: '41'});
    backend = Backend();
    transport = Transport();
    agent = AgentController(client: Client());
    device = Device();
    voice = VoiceCompanionController(
      backend: backend,
      transport: transport,
      agent: agent,
      authenticated: () => true,
      device: device,
      delay: (_) async {},
    );
  });
  test(
    'Fish session budget fallback exits Thinking and offers explicit device speech',
    () async {
      await voice.start(AppLanguage.english);
      transport.event('processing', 1, turnId: 't1');
      transport.event(
        'agent_result',
        2,
        turnId: 't1',
        payload: {'result': result},
      );
      transport.event(
        'fallback_required',
        3,
        turnId: 't1',
        payload: {
          'component': 'tts',
          'code': 'FISH_REQUEST_LIMIT',
          'deviceTts': {'playbackId': 'budget-p1', 'text': result['reply']},
        },
      );
      await Future<void>.delayed(Duration.zero);
      expect(voice.state, 'recovering');
      expect(agent.messages.single.text, result['reply']);
      expect(device.spoken, isEmpty);
      await voice.speakDeviceFallback();
      expect(device.spoken, [result['reply']]);
      expect(voice.state, 'listening');
      expect(transport.controls.last['type'], 'playback_complete');
    },
  );
  test(
    'slow or lost Worker processing event cannot leave Thinking forever',
    () async {
      voice.dispose();
      voice = VoiceCompanionController(
        backend: backend,
        transport: transport,
        agent: agent,
        authenticated: () => true,
        device: device,
        delay: (_) async {},
        processingTimeout: const Duration(milliseconds: 5),
      );
      await voice.start(AppLanguage.english);
      transport.event('processing', 1, turnId: 't1');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(voice.state, 'recovering');
      expect(voice.recoveryCode, 'VOICE_TURN_DELAYED');
      expect(agent.messages.single.text, result['reply']);
      expect(backend.calls.where((c) => c == 'submit'), isEmpty);
      await voice.end();
    },
  );
  test(
    'completed reconciled receipt clears uncertainty without replaying the action',
    () async {
      await voice.start(AppLanguage.english);
      transport.event('processing', 1, turnId: 't1');
      await Future<void>.delayed(Duration.zero);
      backend.receiptStatus = 'recovery_required';
      expect(await voice.reconcile(), false);
      expect(voice.recoveryRequired, true);
      backend.receiptStatus = 'completed';
      expect(await voice.reconcile(), true);
      expect(voice.recoveryRequired, false);
      expect(backend.calls.where((c) => c == 'submit'), isEmpty);
      await voice.resume();
      expect(voice.state, 'listening');
    },
  );
  test(
    'resuming after a speech fallback discards its stale device playback offer',
    () async {
      await voice.start(AppLanguage.english);
      transport.event(
        'fallback_required',
        1,
        turnId: 't1',
        payload: {
          'component': 'tts',
          'code': 'FISH_REQUEST_LIMIT',
          'deviceTts': {'playbackId': 'old-audio', 'text': 'Old answer'},
        },
      );
      await Future<void>.delayed(Duration.zero);
      expect(voice.hasDeviceTtsOffer, true);
      await voice.resume();
      expect(voice.hasDeviceTtsOffer, false);
      await voice.speakDeviceFallback();
      expect(device.spoken, isEmpty);
    },
  );
  test(
    'late completed Worker result clears only its matching uncertain turn',
    () async {
      await voice.start(AppLanguage.english);
      transport.event('processing', 1, turnId: 'late-turn');
      await Future<void>.delayed(Duration.zero);
      backend.receiptStatus = 'recovery_required';
      expect(await voice.reconcile(), false);
      expect(voice.recoveryRequired, true);
      transport.event(
        'agent_result',
        2,
        turnId: 'late-turn',
        payload: {'result': result},
      );
      await Future<void>.delayed(Duration.zero);
      expect(voice.recoveryRequired, false);
      await voice.resume();
      expect(voice.state, 'listening');
    },
  );
  test(
    'manual mute prevents the processing watchdog from changing user intent',
    () async {
      voice.dispose();
      voice = VoiceCompanionController(
        backend: backend,
        transport: transport,
        agent: agent,
        authenticated: () => true,
        device: device,
        delay: (_) async {},
        processingTimeout: const Duration(milliseconds: 5),
      );
      await voice.start(AppLanguage.english);
      transport.event('processing', 1, turnId: 'muted-turn');
      await Future<void>.delayed(Duration.zero);
      await voice.mute();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(voice.state, 'muted');
      expect(transport.mic, false);
      await voice.end();
    },
  );
  test(
    'five consecutive Worker turns complete exactly once and keep the microphone available',
    () async {
      await voice.start(AppLanguage.english);
      var seq = 0;
      for (var turn = 0; turn < 5; turn++) {
        final id = 'multi-$turn';
        transport.event('processing', ++seq, turnId: id);
        transport.event(
          'agent_result',
          ++seq,
          turnId: id,
          payload: {'result': result},
        );
        transport.event(
          'speaking',
          ++seq,
          turnId: id,
          payload: {'playbackId': 'audio-$turn'},
        );
        transport.event(
          'playback_complete',
          ++seq,
          turnId: id,
          payload: {'playbackId': 'audio-$turn'},
        );
        await Future<void>.delayed(Duration.zero);
        expect(voice.state, 'listening');
        expect(transport.mic, true);
      }
      expect(agent.messages.length, 5);
      expect(backend.calls.where((c) => c == 'submit'), isEmpty);
    },
  );
  test(
    'mute while reconnect token is pending never republishes microphone',
    () async {
      await voice.start(AppLanguage.english);
      transport.connectionController.add(VoiceConnection.disconnected);
      await Future<void>.delayed(Duration.zero);
      backend.renewal = Completer();
      final resuming = voice.resume();
      await Future<void>.delayed(Duration.zero);
      await voice.mute();
      backend.renewal!.complete(binding());
      await resuming;
      expect(transport.mic, false);
      expect(voice.muted, true);
    },
  );
  testWidgets('application scope and active microphone survive navigation', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (_, child) =>
            VoiceCompanionScope(controller: voice, child: child!),
        routes: {
          '/': (_) => const Text('Agent'),
          '/settings': (_) => Builder(
            builder: (context) {
              expect(VoiceCompanionScope.maybeOf(context), same(voice));
              return const Text('Settings');
            },
          ),
        },
      ),
    );
    await tester.runAsync(() => voice.start(AppLanguage.english));
    unawaited(
      const AgentNavigationHandler().navigate(
        navigator.currentState!.overlay!.context,
        const AgentNavigation(target: 'settings'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(transport.connects, 1);
    expect(transport.mic, true);
  });
  test(
    'deduplicated confirmation uses canonical receipt without polling a nonexistent turn',
    () async {
      await voice.start(AppLanguage.english);
      backend.canonicalTurn = 'consumed-confirmation';
      await voice.submitManual(
        '',
        confirmation: {'confirmationId': 'c1', 'decision': 'confirm'},
      );
      expect(backend.calls, isNot(contains('receipt')));
      expect(voice.recoveryRequired, false);
      expect(transport.controls.last['turnId'], 'consumed-confirmation');
      await voice.submitManual('Next question');
      expect(backend.calls.where((c) => c == 'submit').length, 2);
    },
  );
  test(
    'manual to worker resumes with one connection and the new epoch',
    () async {
      await voice.start(AppLanguage.english);
      await voice.manual();
      await voice.resume();
      expect(transport.connects, 2);
      expect(voice.epoch, 3);
      expect(transport.controls.last['type'], 'resume');
    },
  );
  test(
    'device fallback preserves UTF16 suffix and receipt language and plays once',
    () async {
      await voice.start(AppLanguage.english);
      final original = Map<String, dynamic>.from(result);
      addTearDown(() {
        result
          ..clear()
          ..addAll(original);
      });
      result['reply'] = 'A😀 باقی دوا';
      result['language'] = 'ur';
      final payload = {
        'component': 'tts',
        'deviceTts': {
          'playbackId': 'device-p1',
          'textViaUserApi': true,
          'textStartOffset': 4,
        },
      };
      transport.event('fallback_required', 1, turnId: 't1', payload: payload);
      await Future<void>.delayed(Duration.zero);
      await voice.speakDeviceFallback();
      transport.event('fallback_required', 2, turnId: 't1', payload: payload);
      await Future<void>.delayed(Duration.zero);
      expect(device.spoken, ['باقی دوا']);
      expect(device.languages, [AppLanguage.urdu]);
      expect(
        transport.controls
            .where((c) => c['type'] == 'playback_complete')
            .length,
        1,
      );
    },
  );
  test(
    'mute during device speech prevents late acknowledgement and microphone rearm',
    () async {
      await voice.start(AppLanguage.english);
      transport.event(
        'fallback_required',
        1,
        turnId: 't1',
        payload: {
          'component': 'tts',
          'deviceTts': {'playbackId': 'p1', 'text': 'Hello'},
        },
      );
      await Future<void>.delayed(Duration.zero);
      device.speaking = Completer<void>();
      final speaking = voice.speakDeviceFallback();
      await Future<void>.delayed(Duration.zero);
      await voice.mute();
      await speaking;
      expect(transport.mic, false);
      expect(
        transport.controls.where((c) => c['type'] == 'playback_complete'),
        isEmpty,
      );
    },
  );
  test(
    'device recognizer takes a new epoch and blank final text never executes',
    () async {
      await voice.start(AppLanguage.english);
      await voice.useDeviceSpeech();
      expect(voice.transportOwner, 'device');
      expect(voice.epoch, 2);
      expect(transport.mic, false);
      expect(device.isListening, true);
      device.completed!();
      await Future<void>.delayed(Duration.zero);
      expect(backend.calls, isNot(contains('submit')));
      await voice.end();
      device.completed!();
      expect(device.isListening, false);
    },
  );
  tearDown(() async {
    await voice.end();
    voice.dispose();
    agent.dispose();
  });
  test(
    'permission dialog inactivity preserves start, actual background closes audio without auto-resume',
    () async {
      await voice.start(AppLanguage.english);
      await voice.lifecycle(AppLifecycleState.inactive);
      expect(voice.enabled, true);
      expect(transport.mic, true);
      await voice.lifecycle(AppLifecycleState.hidden);
      expect(voice.enabled, false);
      expect(transport.mic, false);
      await voice.lifecycle(AppLifecycleState.resumed);
      expect(voice.foreground, true);
      expect(transport.mic, false);
    },
  );
  test(
    'primary Fish speech for a normal Agent result never requires opting into device TTS',
    () async {
      await voice.start(AppLanguage.english);
      transport.event(
        'agent_result',
        1,
        turnId: 't1',
        payload: {'result': result},
      );
      transport.event(
        'speaking',
        2,
        turnId: 't1',
        payload: {'provider': 'fish', 'playbackId': 'p1'},
      );
      await Future<void>.delayed(Duration.zero);
      expect(voice.state, 'speaking');
      expect(device.spoken, isEmpty);
      expect(voice.hasDeviceTtsOffer, false);
      transport.event('playback_complete', 3, payload: {'playbackId': 'p1'});
      await Future<void>.delayed(Duration.zero);
      expect(voice.state, 'listening');
      expect(transport.mic, true);
    },
  );
  for (final viaReceipt in [false, true]) {
    test(
      'completed voice result exits Thinking without muting (receipt=$viaReceipt)',
      () async {
        await voice.start(AppLanguage.english);
        transport.event('processing', 1, turnId: 't1');
        await Future<void>.delayed(Duration.zero);
        expect(voice.state, 'processing');
        expect(transport.mic, true);
        expect(transport.microphoneChanges, isNot(contains(false)));
        expect(transport.controls.where((c) => c['type'] == 'mute'), isEmpty);
        transport.event(
          'agent_result',
          2,
          turnId: 't1',
          payload: viaReceipt ? {'resultViaUserApi': true} : {'result': result},
        );
        await Future<void>.delayed(Duration.zero);
        expect(agent.messages.single.text, result['reply']);
        expect(voice.state, 'listening');
        expect(voice.eligibleCheckIn, true);
        expect(transport.mic, true);
        transport.event(
          'speaking',
          3,
          turnId: 't1',
          payload: {'playbackId': 'p1'},
        );
        await Future<void>.delayed(Duration.zero);
        expect(voice.state, 'speaking');
        expect(transport.mic, true);
        await voice.interrupt();
        expect(transport.controls.any((c) => c['type'] == 'interrupt'), true);
      },
    );
  }
  for (final preserved in ['muted', 'recovering', 'speaking', 'processing']) {
    test(
      'completed older turn preserves $preserved state and microphone',
      () async {
        await voice.start(AppLanguage.english);
        transport.event('processing', 1, turnId: 't1');
        await Future<void>.delayed(Duration.zero);
        if (preserved == 'muted') {
          await voice.mute();
        } else if (preserved == 'recovering') {
          transport.connectionController.add(VoiceConnection.reconnecting);
        } else if (preserved == 'speaking') {
          transport.event(
            'speaking',
            2,
            turnId: 't1',
            payload: {'playbackId': 'p1'},
          );
        } else {
          transport.event('processing', 2, turnId: 't2');
        }
        await Future<void>.delayed(Duration.zero);
        final mic = transport.mic;
        final micCalls = transport.microphoneChanges.length;
        transport.event(
          'agent_result',
          3,
          turnId: 't1',
          payload: {'result': result},
        );
        await Future<void>.delayed(Duration.zero);
        expect(agent.messages.single.text, result['reply']);
        expect(voice.state, preserved);
        expect(transport.mic, mic);
        expect(transport.microphoneChanges.length, micCalls);
      },
    );
  }
  test(
    'completed manual turn requests receipt playback without sending reply text',
    () async {
      await voice.start(AppLanguage.english);
      await voice.submitManual('Ask about my fictional walk');
      final request = transport.controls.singleWhere(
        (c) => c['type'] == 'receipt_ready',
      );
      expect(request['turnId'], isA<String>());
      expect(
        request.keys,
        unorderedEquals([
          'v',
          'type',
          'voiceSessionId',
          'epoch',
          'seq',
          'turnId',
        ]),
      );
      expect(backend.calls.where((c) => c == 'submit').length, 1);
      expect(agent.messages.last.text, result['reply']);
    },
  );
  test(
    'reconnection reconciles a server turn whose processing event was lost',
    () async {
      await voice.start(AppLanguage.english);
      backend.activeTurn = 'lost-turn';
      transport.connectionController.add(VoiceConnection.reconnected);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(backend.calls.where((c) => c == 'receipt').length, 1);
      expect(agent.messages.last.text, result['reply']);
      expect(backend.calls, isNot(contains('submit')));
    },
  );
  test(
    'explicit resume after disconnection fetches a fresh room token',
    () async {
      await voice.start(AppLanguage.english);
      transport.connectionController.add(VoiceConnection.disconnected);
      await Future<void>.delayed(Duration.zero);
      await voice.resume();
      expect(backend.calls, contains('token'));
      expect(transport.connects, 2);
    },
  );
  test(
    'authorized Worker binding targets controls and Fish permits spoken interruption',
    () async {
      await voice.start(AppLanguage.english);
      transport.event('ready', 1);
      transport.event('speaking', 2, payload: {'playbackId': 'p1'});
      await Future<void>.delayed(Duration.zero);
      expect(transport.worker, 'agent-job');
      expect(transport.mic, true);
      await voice.interrupt();
      expect(transport.controls.any((c) => c['type'] == 'interrupt'), true);
    },
  );
  test(
    'late unknown playback completion cannot rearm a processing microphone',
    () async {
      await voice.start(AppLanguage.english);
      transport.mic = false;
      transport.event(
        'playback_complete',
        1,
        payload: {'playbackId': 'obsolete'},
      );
      await Future<void>.delayed(Duration.zero);
      expect(transport.mic, false);
    },
  );
  test(
    'explicit start publishes mic; mute and end never automatically resume',
    () async {
      expect(transport.connects, 0);
      await voice.start(AppLanguage.english);
      expect(transport.mic, true);
      await voice.mute();
      transport.event('playback_complete', 1);
      await Future<void>.delayed(Duration.zero);
      expect(transport.mic, false);
      await voice.end();
      transport.event('ready', 2);
      expect(transport.mic, false);
      expect(voice.enabled, false);
    },
  );
  test(
    'stale epochs, foreign senders and duplicate events cannot append Agent results',
    () async {
      await voice.start(AppLanguage.english);
      transport.event('ready', 1);
      transport.event(
        'agent_result',
        2,
        epoch: 2,
        turnId: 't1',
        payload: {'result': result},
      );
      transport.event(
        'agent_result',
        2,
        sender: 'user-evil',
        turnId: 't1',
        payload: {'result': result},
      );
      transport.event(
        'agent_result',
        2,
        turnId: 't1',
        payload: {'result': result},
      );
      transport.event(
        'agent_result',
        2,
        turnId: 't1',
        payload: {'result': result},
      );
      await Future<void>.delayed(Duration.zero);
      expect(agent.messages.length, 1);
      expect(agent.messages.single.text, result['reply']);
    },
  );
  test(
    'speech playback permits VAD interruption and completion keeps continuous listening',
    () async {
      await voice.start(AppLanguage.english);
      transport.event('ready', 1);
      transport.event('speaking', 2, payload: {'playbackId': 'p1'});
      await Future<void>.delayed(Duration.zero);
      expect(transport.mic, true);
      transport.event('playback_complete', 3, payload: {'playbackId': 'p1'});
      await Future<void>.delayed(Duration.zero);
      expect(transport.mic, true);
      expect(transport.controls.last['type'], 'resume');
    },
  );
  test(
    'manual transport handoff first reconciles uncertain receipt without replay',
    () async {
      await voice.start(AppLanguage.english);
      transport.event('ready', 1);
      transport.event('processing', 2, turnId: 't1');
      await voice.manual();
      expect(backend.calls.where((c) => c == 'receipt').length, 1);
      expect(backend.calls, contains('transfer:manual'));
      expect(backend.calls, isNot(contains('submit')));
      expect(voice.epoch, 2);
    },
  );
  test('unresolved receipt blocks transfer and keeps microphone off', () async {
    await voice.start(AppLanguage.english);
    backend.receiptStatus = 'recovery_required';
    transport.event('ready', 1);
    transport.event('processing', 2, turnId: 't1');
    await voice.manual();
    expect(backend.calls, isNot(contains('transfer:manual')));
    expect(voice.recoveryRequired, true);
    expect(transport.mic, false);
  });
  test(
    'end during creation invalidates pending connection and closes newly created room',
    () async {
      backend.creation = Completer();
      final starting = voice.start(AppLanguage.english);
      await Future<void>.delayed(Duration.zero);
      await voice.end();
      backend.creation!.complete(binding());
      await starting;
      expect(transport.connects, 0);
      expect(backend.calls, contains('end'));
      expect(transport.mic, false);
    },
  );
}
