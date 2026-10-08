enum VoiceConnection { connected, reconnecting, reconnected, disconnected }

class VoicePacket {
  const VoicePacket(this.sender, this.topic, this.value);
  final String sender;
  final String topic;
  final Map<String, dynamic> value;
}

abstract interface class VoiceTransport {
  Stream<VoicePacket> get events;
  Stream<VoiceConnection> get connections;
  Future<void> connect(Map<String, dynamic> session);
  Future<void> bindWorker(String identity);
  Future<void> microphone(bool enabled);
  Future<void> send(Map<String, dynamic> value);
  Future<void> disconnect();
}
