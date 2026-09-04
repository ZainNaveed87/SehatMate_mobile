import 'dart:convert';
import 'dart:typed_data';

class AgentSpeech {
  const AgentSpeech({
    required this.audioBase64,
    required this.contentType,
    required this.format,
    required this.model,
  });

  final String audioBase64;
  final String contentType;
  final String format;
  final String model;

  Uint8List get audioBytes => base64Decode(audioBase64);

  factory AgentSpeech.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Agent speech must be an object.');
    }
    if (value['failed'] == true) {
      throw const FormatException('Agent speech failed.');
    }
    final audioBase64 = value['audioBase64']?.toString() ?? '';
    final contentType = value['contentType']?.toString() ?? '';
    final format = value['format']?.toString() ?? '';
    final model = value['model']?.toString() ?? '';
    if (audioBase64.isEmpty ||
        contentType != 'audio/mpeg' ||
        format != 'mp3' ||
        model.isEmpty) {
      throw const FormatException('Agent speech is invalid.');
    }
    return AgentSpeech(
      audioBase64: audioBase64,
      contentType: contentType,
      format: format,
      model: model,
    );
  }
}
