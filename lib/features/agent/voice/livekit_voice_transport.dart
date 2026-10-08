import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'voice_transport.dart';
import 'voice_backend.dart';

class LiveKitVoiceTransport implements VoiceTransport {
  final _events = StreamController<VoicePacket>.broadcast();
  final _connections = StreamController<VoiceConnection>.broadcast();
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  String? _workerIdentity;
  @override
  Stream<VoicePacket> get events => _events.stream;
  @override
  Stream<VoiceConnection> get connections => _connections.stream;
  @override
  Future<void> connect(Map<String, dynamic> session) async {
    await disconnect();
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
      ..on<RoomDisconnectedEvent>((_) {
        if (_room == room) _connections.add(VoiceConnection.disconnected);
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
        await room.disconnect();
        return;
      }
      if (room.localParticipant?.identity != session['participantIdentity']) {
        throw const VoiceFailure('VOICE_PARTICIPANT_MISMATCH');
      }
      _connections.add(VoiceConnection.connected);
    } catch (_) {
      if (_room == room) await disconnect();
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
    await _room?.localParticipant?.setMicrophoneEnabled(enabled);
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
  Future<void> disconnect() async {
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
  }
}
