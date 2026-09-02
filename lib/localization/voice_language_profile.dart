import 'app_language.dart';

class VoiceLanguageProfile {
  const VoiceLanguageProfile({
    required this.agentLanguageCode,
    required this.inputLocale,
    required this.outputLocale,
    required this.displayMode,
    required this.agentInstruction,
    required this.requiresSeparateSpeechText,
  });

  final String agentLanguageCode;
  final String inputLocale;
  final String outputLocale;

  /// english | urdu_script | roman_urdu
  final String displayMode;

  final String agentInstruction;

  /// Roman Urdu should be displayed in Latin letters, but the Voice Agent
  /// should also return Urdu-script speechText for more natural Urdu TTS.
  final bool requiresSeparateSpeechText;

  factory VoiceLanguageProfile.forLanguage(AppLanguage language) {
    return VoiceLanguageProfile(
      agentLanguageCode: language.agentLanguageCode,
      inputLocale: language.speechRecognitionLocale,
      outputLocale: language.ttsLocale,
      displayMode: switch (language) {
        AppLanguage.english => 'english',
        AppLanguage.urdu => 'urdu_script',
        AppLanguage.romanUrdu => 'roman_urdu',
      },
      agentInstruction: language.agentLanguageInstruction,
      requiresSeparateSpeechText: language == AppLanguage.romanUrdu,
    );
  }

  Map<String, dynamic> toAgentJson() => {
        'language': agentLanguageCode,
        'inputLocale': inputLocale,
        'outputLocale': outputLocale,
        'displayMode': displayMode,
        'requiresSeparateSpeechText': requiresSeparateSpeechText,
      };
}
