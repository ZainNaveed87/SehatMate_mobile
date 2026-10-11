import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sehatmate_ai/features/agent/controllers/agent_controller.dart';
import 'package:sehatmate_ai/features/agent/services/agent_session_store.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_controller.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_transport.dart';
import 'package:sehatmate_ai/localization/app_language.dart';
import 'voice_companion_controller_test.dart' as fixture;

class DelayedBackend extends fixture.Backend {
  Completer<Map<String,dynamic>>? lookup;
  @override Future<Map<String,dynamic>> get(String id) => lookup?.future??super.get(id);
}
class DelayedMicrophone extends fixture.Transport {
  Completer<void>? nextDisable;
  @override Future<void> microphone(bool enabled) async {
    final hold=enabled?null:nextDisable;
    if(hold!=null)nextDisable=null;
    await hold?.future;
    await super.microphone(enabled);
  }
}
class DelayedControl extends fixture.Transport {
  Completer<void>? nextControl;
  @override Future<void> send(Map<String,dynamic> value) async {
    final hold=nextControl;nextControl=null;
    await hold?.future;
    await super.send(value);
  }
}
class DelayedReceipt extends fixture.Backend {
  Completer<Map<String,dynamic>>? pendingReceipt;
  @override Future<Map<String,dynamic>> receipt(String id,String turnId) => pendingReceipt?.future??super.receipt(id,turnId);
}
class DelayedResumeTransport extends fixture.Transport {
  Completer<void>? nextConnect, nextEnable;
  @override Future<void> connect(Map<String,dynamic> value) async {
    final hold=nextConnect;nextConnect=null;
    await hold?.future;await super.connect(value);
  }
  @override Future<void> microphone(bool enabled) async {
    final hold=enabled?nextEnable:null;
    if(enabled)nextEnable=null;
    await hold?.future;await super.microphone(enabled);
  }
}
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({AgentSessionStore.key:'41'}));
  test('visual action failure preserves authoritative reply and healthy voice input', () async {
    final backend=fixture.Backend(),transport=fixture.Transport();
    final agent=AgentController(client:fixture.Client(),onCopilotResult:(_,_)async{throw StateError('visual action failed');});
    final voice=VoiceCompanionController(backend:backend,transport:transport,agent:agent,authenticated:()=>true);
    await voice.start(AppLanguage.english);
    transport.event('processing',1,turnId:'turn');
    transport.event('agent_result',2,turnId:'turn',payload:{'result':fixture.result});
    await Future<void>.delayed(const Duration(milliseconds:30));
    expect(voice.reply,fixture.result['reply']);expect(voice.muted,false);
    expect(voice.recoveryRequired,false);expect(transport.mic,true);
    expect(backend.calls,isNot(contains('end')));
    await voice.end();voice.dispose();agent.dispose();
  });
  test('old reconnect lookup cannot end a newer connected session', () async {
    final backend=DelayedBackend(),transport=fixture.Transport(),agent=AgentController(client:fixture.Client());
    final voice=VoiceCompanionController(backend:backend,transport:transport,agent:agent,authenticated:()=>true);
    await voice.start(AppLanguage.english);backend.lookup=Completer();
    transport.connectionController.add(VoiceConnection.reconnected);
    await Future<void>.delayed(Duration.zero);
    await voice.end();await voice.start(AppLanguage.english);
    backend.lookup!.complete(fixture.binding());await Future<void>.delayed(const Duration(milliseconds:20));
    expect(voice.enabled,true);expect(voice.state,'listening');expect(transport.mic,true);
    expect(backend.calls.where((c)=>c=='end').length,1);
    await voice.end();voice.dispose();agent.dispose();
  });
  test('invalid result gates input as recovery, never manual mute', () async {
    final backend=fixture.Backend(),transport=fixture.Transport(),agent=AgentController(client:fixture.Client());
    final voice=VoiceCompanionController(backend:backend,transport:transport,agent:agent,authenticated:()=>true);
    await voice.start(AppLanguage.english);
    transport.event('agent_result',1,turnId:'turn',payload:{'result':{...fixture.result,'sessionId':'rejected'}});
    await Future<void>.delayed(const Duration(milliseconds:15));
    expect(voice.muted,false);expect(voice.automaticInputGated,true);expect(voice.recoveryRequired,true);expect(transport.mic,false);
    await voice.end();voice.dispose();agent.dispose();
  });
  test('explicit mute and resume retain user semantics during speaking and confirmation', () async {
    final transport=fixture.Transport(),agent=AgentController(client:fixture.Client());
    final voice=VoiceCompanionController(backend:fixture.Backend(),transport:transport,agent:agent,authenticated:()=>true);
    await voice.start(AppLanguage.english);transport.event('speaking',1,payload:{'playbackId':'playback'});
    await Future<void>.delayed(Duration.zero);expect(voice.muted,false);expect(transport.mic,true);
    await voice.mute();expect(voice.muted,true);expect(voice.automaticInputGated,false);expect(transport.mic,false);
    await voice.resume();transport.event('awaiting_confirmation',2);await Future<void>.delayed(Duration.zero);
    expect(voice.muted,false);expect(transport.mic,true);expect(voice.enabled,true);
    await voice.end();expect(voice.enabled,false);expect(transport.mic,false);voice.dispose();agent.dispose();
  });
  test('new startup waits for prior asynchronous teardown', () async {
    final backend=fixture.Backend(),transport=DelayedMicrophone(),agent=AgentController(client:fixture.Client());
    final voice=VoiceCompanionController(backend:backend,transport:transport,agent:agent,authenticated:()=>true);
    await voice.start(AppLanguage.english);final release=Completer<void>();transport.nextDisable=release;
    final ending=voice.end();final starting=voice.start(AppLanguage.english);
    await Future<void>.delayed(Duration.zero);expect(transport.connects,1);
    release.complete();await ending;await starting;expect(transport.connects,2);expect(voice.enabled,true);expect(transport.mic,true);
    await voice.end();voice.dispose();agent.dispose();
  });
  test('old Worker terminal callback cannot disable newer session', () async {
    final transport=DelayedMicrophone(),agent=AgentController(client:fixture.Client());
    final voice=VoiceCompanionController(backend:fixture.Backend(),transport:transport,agent:agent,authenticated:()=>true);
    await voice.start(AppLanguage.english);final release=Completer<void>();transport.nextDisable=release;
    transport.event('disconnected',1);await Future<void>.delayed(Duration.zero);
    await voice.end();await voice.start(AppLanguage.english);release.complete();await Future<void>.delayed(const Duration(milliseconds:15));
    expect(voice.enabled,true);expect(voice.state,'listening');expect(voice.muted,false);
    // The fake completes an obsolete mic call; a real transport captures its old Room.
    await voice.end();voice.dispose();agent.dispose();
  });
  test('old mute control cannot disable the microphone of a newer session', () async {
    final transport=DelayedControl(),agent=AgentController(client:fixture.Client());
    final voice=VoiceCompanionController(backend:fixture.Backend(),transport:transport,agent:agent,authenticated:()=>true);
    await voice.start(AppLanguage.english);final release=Completer<void>();transport.nextControl=release;
    final muting=voice.mute();await Future<void>.delayed(Duration.zero);
    await voice.end();await voice.start(AppLanguage.english);release.complete();await muting;
    expect(voice.enabled,true);expect(voice.muted,false);expect(transport.mic,true);
    await voice.end();voice.dispose();agent.dispose();
  });
  test('old manual handoff cannot transfer or disconnect a newer session', () async {
    final backend=fixture.Backend(),transport=DelayedMicrophone(),agent=AgentController(client:fixture.Client());
    final voice=VoiceCompanionController(backend:backend,transport:transport,agent:agent,authenticated:()=>true);
    await voice.start(AppLanguage.english);final release=Completer<void>();transport.nextDisable=release;
    final handoff=voice.manual();await Future<void>.delayed(Duration.zero);
    await voice.end();await voice.start(AppLanguage.english);release.complete();await handoff;
    expect(voice.enabled,true);expect(voice.state,'listening');expect(backend.calls,isNot(contains('transfer:manual')));
    await voice.end();voice.dispose();agent.dispose();
  });
  test('old failed receipt lookup cannot mark a newer session uncertain', () async {
    final backend=DelayedReceipt(),transport=fixture.Transport(),agent=AgentController(client:fixture.Client());
    final voice=VoiceCompanionController(backend:backend,transport:transport,agent:agent,authenticated:()=>true);
    await voice.start(AppLanguage.english);transport.event('processing',1,turnId:'turn');await Future<void>.delayed(Duration.zero);
    final release=Completer<Map<String,dynamic>>();backend.pendingReceipt=release;
    final recovering=voice.reconcile();await Future<void>.delayed(Duration.zero);
    await voice.end();await voice.start(AppLanguage.english);release.completeError(StateError('old lookup'));await recovering;
    expect(voice.enabled,true);expect(voice.state,'listening');expect(voice.recoveryRequired,false);
    await voice.end();voice.dispose();agent.dispose();
  });

  test('old reconnect lookup cannot end a newer transport epoch', () async {
    final backend=DelayedBackend(),transport=fixture.Transport(),agent=AgentController(client:fixture.Client());
    final voice=VoiceCompanionController(backend:backend,transport:transport,agent:agent,authenticated:()=>true);
    await voice.start(AppLanguage.english);final release=Completer<Map<String,dynamic>>();backend.lookup=release;
    transport.connectionController.add(VoiceConnection.reconnected);await Future<void>.delayed(Duration.zero);
    backend.lookup=null;await voice.manual();expect(voice.epoch,2);
    release.complete(fixture.binding());await Future<void>.delayed(const Duration(milliseconds:15));
    expect(voice.voiceSessionId,isNotNull);expect(voice.state,'manual');expect(backend.calls,isNot(contains('end')));
    await voice.end();voice.dispose();agent.dispose();
  });

  for(final phase in ['connect','microphone']) {
    test('stale resume $phase completion cannot close or mute the newer Room', () async {
      final backend=fixture.Backend(),transport=DelayedResumeTransport(),agent=AgentController(client:fixture.Client());
      final voice=VoiceCompanionController(backend:backend,transport:transport,agent:agent,authenticated:()=>true);
      await voice.start(AppLanguage.english);
      if (phase=='connect') {await voice.manual();} else {await voice.mute();}
      final release=Completer<void>();
      if (phase=='connect') {transport.nextConnect=release;} else {transport.nextEnable=release;}
      final resuming=voice.resume();await Future<void>.delayed(const Duration(milliseconds:5));
      await voice.end();await voice.start(AppLanguage.english);release.complete();await resuming;
      expect(voice.enabled,true);expect(voice.state,'listening');expect(transport.mic,true);expect(voice.muted,false);
      await voice.end();voice.dispose();agent.dispose();
    });
  }

}
