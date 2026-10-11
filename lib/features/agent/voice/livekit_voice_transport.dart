import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'voice_transport.dart';
import 'voice_backend.dart';
import 'voice_lifecycle_trace.dart';

class LiveKitVoiceTransport implements VoiceTransport {
  final _events = StreamController<VoicePacket>.broadcast();
  final _connections = StreamController<VoiceConnection>.broadcast();
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  String? _workerIdentity;
  int _roomGeneration=0;
  void _micState(Room room) {
    if(_room!=room)return;
    traceVoiceLifecycle(VoiceLifecycleEvent.micTrackState,
        VoiceLifecycleReason.microphoneObserved,generation:_roomGeneration,
        micEnabled:room.localParticipant?.isMicrophoneEnabled()??false);
  }
  @override
  Stream<VoicePacket> get events => _events.stream;
  @override
  Stream<VoiceConnection> get connections => _connections.stream;
  @override
  Future<void> connect(Map<String, dynamic> session) async {
    await _closeRoom(VoiceLifecycleReason.start);
    final url = Uri.tryParse(session['livekitUrl']?.toString() ?? '');
    if (url?.scheme != 'wss' ||
        url!.host.isEmpty ||
        session['token'] is! String) {
      throw const VoiceFailure('VOICE_INVALID_ROOM_TOKEN');
    }
    final room = Room(
      roomOptions: const RoomOptions(
        defaultAudioCaptureOptions: AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        ),
      ),
    );
    _room = room;
    final generation=++_roomGeneration;
    traceVoiceLifecycle(VoiceLifecycleEvent.sessionState,VoiceLifecycleReason.start,
        generation:generation,state:'connecting');
    _workerIdentity = session['workerIdentity'] as String?;
    _listener = room.createListener()
      ..on<DataReceivedEvent>((event) {
        if (_room != room ||
            event.topic != 'sehatmate.voice.v1' ||
            event.data.length > 12000 ||
            event.participant == null) {
          return;
        }
        try {
          final value = jsonDecode(utf8.decode(event.data));
          if (value is Map<String, dynamic>) {
            _events.add(
              VoicePacket(event.participant!.identity, event.topic!, value),
            );
          }
        } catch (_) {}
      })
      ..on<RoomReconnectingEvent>((_) {
        if (_room == room) _connections.add(VoiceConnection.reconnecting);
      })
      ..on<RoomReconnectedEvent>((_) {
        if (_room == room) _connections.add(VoiceConnection.reconnected);
      })
      ..on<RoomDisconnectedEvent>((event) {
        if (_room == room) {
          traceVoiceLifecycle(VoiceLifecycleEvent.sessionState,
              VoiceLifecycleReason.transportLost,generation:generation,state:'disconnected',disconnectCause:event.reason?.name??'unknown');
          _connections.add(VoiceConnection.disconnected);
        }
      })
      ..on<TrackMutedEvent>((event) {
        if(identical(event.participant,room.localParticipant)&&event.publication.source==TrackSource.microphone)_micState(room);
      })
      ..on<TrackUnmutedEvent>((event) {
        if(identical(event.participant,room.localParticipant)&&event.publication.source==TrackSource.microphone)_micState(room);
      })
      ..on<LocalTrackPublishedEvent>((event) {
        if(event.publication.source==TrackSource.microphone)_micState(room);
      })
      ..on<TrackPublishedEvent>((event) {
        if (_room == room &&
            event.participant.identity == _workerIdentity &&
            event.publication.kind == TrackType.AUDIO) {
          debugPrint('VOICE_AUDIO_TRACK:SUBSCRIPTION_REQUESTED');
          unawaited(
            event.publication.subscribe().catchError((Object _) {
              debugPrint('VOICE_AUDIO_TRACK:SUBSCRIPTION_FAILED');
              if (_room == room) _connections.add(VoiceConnection.disconnected);
            }),
          );
        }
      });
    try {
      await room
          .connect(
            url.toString(),
            session['token'],
            connectOptions: const ConnectOptions(autoSubscribe: false),
          )
          .timeout(const Duration(seconds: 20));
      if (_room != room) {
        traceVoiceLifecycle(VoiceLifecycleEvent.disconnectStarted,
            VoiceLifecycleReason.staleStartup,generation:generation);
        await room.disconnect();
        return;
      }
      if (room.localParticipant?.identity != session['participantIdentity']) {
        throw const VoiceFailure('VOICE_PARTICIPANT_MISMATCH');
      }
      _connections.add(VoiceConnection.connected);
      traceVoiceLifecycle(VoiceLifecycleEvent.sessionState,VoiceLifecycleReason.start,
          generation:generation,state:'listening');
    } catch (_) {
      if (_room == room) await _closeRoom(VoiceLifecycleReason.startupFailed);
      rethrow;
    }
  }

  @override
  Future<void> bindWorker(String identity) async {
    _workerIdentity = identity;
    final room = _room;
    if (room == null) return;
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.trackPublications.values) {
        if (participant.identity == identity &&
            publication.kind == TrackType.AUDIO) {
          debugPrint('VOICE_AUDIO_TRACK:SUBSCRIPTION_REQUESTED');
          await publication.subscribe();
        } else if (publication.subscribed) {
          await publication.unsubscribe();
        }
      }
    }
  }

  @override
  Future<void> microphone(bool enabled) async {
    final room=_room;
    await room?.localParticipant?.setMicrophoneEnabled(enabled);
    if(room!=null)_micState(room);
  }

  @override
  Future<void> send(Map<String, dynamic> value) async {
    final local = _room?.localParticipant;
    if (local == null || _workerIdentity == null) {
      throw const VoiceFailure('VOICE_NOT_CONNECTED');
    }
    await local.publishData(
      utf8.encode(jsonEncode(value)),
      reliable: true,
      topic: 'sehatmate.voice.control.v1',
      destinationIdentities: [_workerIdentity!],
    );
  }

  @override
  Future<void> disconnect() => _closeRoom(VoiceLifecycleReason.transportClose);
  Future<void> _closeRoom(VoiceLifecycleReason reason) async {
    traceVoiceLifecycle(VoiceLifecycleEvent.disconnectStarted,
        reason,generation:_roomGeneration);
    final room = _room;
    _room = null;
    _workerIdentity = null;
    final listener = _listener;
    _listener = null;
    await listener?.dispose();
    if (room != null) {
      try {
        await room.localParticipant?.setMicrophoneEnabled(false);
      } finally {
        await room.disconnect();
        await room.dispose();
      }
    }
    traceVoiceLifecycle(VoiceLifecycleEvent.disconnectCompleted,
        reason,generation:_roomGeneration);
  }
}
