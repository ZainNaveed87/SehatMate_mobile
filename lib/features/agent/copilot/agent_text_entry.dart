import 'dart:async';
import 'dart:math' show min;
import 'package:flutter/widgets.dart';
import '../voice/voice_lifecycle_trace.dart';

/// Writes only to the real field. External edits/selection changes win; a new
/// fill owns one timer and supersedes its predecessor without stale writes.
class AgentTextEntry extends ChangeNotifier {
  AgentTextEntry(this.controller) {controller.addListener(_edited);}
  final TextEditingController controller;
  Timer? _timer;
  TextEditingValue? _owned;
  bool _writing=false, _disposed=false;
  int _generation=0;
  bool get isAnimating => _timer!=null;
  bool get ownsText => _owned!=null && controller.text==_owned!.text;
  void _edited() {
    if(!_writing && controller.value!=_owned) { _owned=null;cancel(); }
  }
  void cancel() {
    if (isAnimating) {
      traceVoiceLifecycle(VoiceLifecycleEvent.actionCompleted,
          VoiceLifecycleReason.actionFailed,generation:_generation,action:'fill_text');
    }
    _timer?.cancel();_timer=null;_owned=null;
    if(!_disposed)notifyListeners();
  }
  void fill(String value,{bool animate=true}) {
    if(_disposed)return;
    cancel();
    ++_generation;
    traceVoiceLifecycle(VoiceLifecycleEvent.actionStarted,
        VoiceLifecycleReason.action,generation:_generation,action:'fill_text');
    final characters=value.characters.toList();
    if(!animate||characters.isEmpty){_write(value);_completed();notifyListeners();return;}
    final steps=min(characters.length,24);
    final interval=Duration(microseconds:min(28000,420000~/steps));
    var tick=0;
    // Mark the existing value as owned until the first deterministic tick.
    _owned=controller.value;
    _timer=Timer.periodic(interval,(timer) {
      if(_disposed || controller.value!=_owned){cancel();return;}
      tick++;
      final count=(characters.length*tick/steps).ceil();
      _write(characters.take(count).join());
      if(tick==steps){_timer?.cancel();_timer=null;_completed();}
      notifyListeners();
    });
    notifyListeners();
  }
  void _completed()=>traceVoiceLifecycle(VoiceLifecycleEvent.actionCompleted,
      VoiceLifecycleReason.action,generation:_generation,action:'fill_text');
  void _write(String value) {
    _owned=TextEditingValue(text:value,selection:TextSelection.collapsed(offset:value.length));
    _writing=true;
    try {controller.value=_owned!;} finally {_writing=false;}
  }
  @override void dispose() {
    _disposed=true;_timer?.cancel();_timer=null;
    controller.removeListener(_edited);super.dispose();
  }
}
