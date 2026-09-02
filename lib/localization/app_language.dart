import 'package:flutter/material.dart';

enum AppLanguage {
  english,
  urdu,
  romanUrdu,
}

extension AppLanguageX on AppLanguage {
  String get storageValue => switch (this) {
        AppLanguage.english => 'english',
        AppLanguage.urdu => 'urdu',
        AppLanguage.romanUrdu => 'roman_urdu',
      };

  String get displayName => switch (this) {
        AppLanguage.english => 'English',
        AppLanguage.urdu => 'اردو',
        AppLanguage.romanUrdu => 'Roman Urdu',
      };

  String get shortLabel => switch (this) {
        AppLanguage.english => 'EN',
        AppLanguage.urdu => 'اردو',
        AppLanguage.romanUrdu => 'RU',
      };

  bool get isRtl => this == AppLanguage.urdu;

  TextDirection get textDirection =>
      isRtl ? TextDirection.rtl : TextDirection.ltr;

  /// Locale used by Flutter's built-in Material/Cupertino widgets.
  ///
  /// Roman Urdu intentionally uses English locale because its UI is LTR.
  Locale get materialLocale => switch (this) {
        AppLanguage.english => const Locale('en'),
        AppLanguage.urdu => const Locale('ur', 'PK'),
        AppLanguage.romanUrdu => const Locale('en', 'PK'),
      };

  /// Language code sent to the SehatMate AI agent.
  String get agentLanguageCode => switch (this) {
        AppLanguage.english => 'en',
        AppLanguage.urdu => 'ur',
        AppLanguage.romanUrdu => 'roman_ur',
      };

  /// Preferred speech recognition locale.
  ///
  /// Roman Urdu users normally speak Urdu, so speech recognition uses ur-PK
  /// while the visible response remains Roman Urdu.
  String get speechRecognitionLocale => switch (this) {
        AppLanguage.english => 'en-US',
        AppLanguage.urdu => 'ur-PK',
        AppLanguage.romanUrdu => 'ur-PK',
      };

  /// Preferred spoken-output locale.
  String get ttsLocale => switch (this) {
        AppLanguage.english => 'en-US',
        AppLanguage.urdu => 'ur-PK',
        AppLanguage.romanUrdu => 'ur-PK',
      };

  /// System instruction that the future Voice Agent can reuse.
  String get agentLanguageInstruction => switch (this) {
        AppLanguage.english =>
          'Reply in clear, simple English. Keep medical wording easy to understand.',
        AppLanguage.urdu =>
          'Reply in clear, simple Urdu using Urdu script. Avoid unnecessary English.',
        AppLanguage.romanUrdu =>
          'Reply in simple Roman Urdu using Latin letters. Keep medical terms easy to understand. '
          'Also provide a separate Urdu-script speechText for natural Urdu TTS.',
      };

  static AppLanguage fromStorage(String? value) {
    final normalized = (value ?? '').trim().toLowerCase().replaceAll('-', '_');

    return switch (normalized) {
      'urdu' || 'ur' || 'ur_pk' => AppLanguage.urdu,
      'romanurdu' ||
      'roman_urdu' ||
      'roman urdu' ||
      'romanur' ||
      'roman_ur' =>
        AppLanguage.romanUrdu,
      _ => AppLanguage.english,
    };
  }
}

const supportedMaterialLocales = <Locale>[
  Locale('en'),
  Locale('en', 'PK'),
  Locale('ur', 'PK'),
];
