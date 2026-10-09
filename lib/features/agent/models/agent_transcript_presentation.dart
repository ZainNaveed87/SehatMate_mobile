import '../../../localization/app_language.dart';

final _arabicLetters = RegExp(
  r'[\u0621-\u063a\u0641-\u064a\u066e-\u06d3\u06fa-\u06fc]',
);
final _numbers = RegExp(
  r'[0-9\u0660-\u0669\u06f0-\u06f9]+(?:[.:/][0-9\u0660-\u0669\u06f0-\u06f9]+)*',
);

bool needsRomanTranscript(String raw, AppLanguage language) =>
    language == AppLanguage.romanUrdu && _arabicLetters.hasMatch(raw);

String? validatedRomanTranscript(String raw, String? candidate) {
  if (candidate == null ||
      candidate.trim().isEmpty ||
      candidate.length > 3000 ||
      _arabicLetters.hasMatch(candidate) ||
      RegExp(
        r'[\u0000-\u001f\u007f\u202a-\u202e\u2066-\u2069]',
      ).hasMatch(candidate)) {
    return null;
  }
  final originalNumbers = _numbers
      .allMatches(raw)
      .map((m) => m.group(0))
      .toList();
  final renderedNumbers = _numbers
      .allMatches(candidate)
      .map((m) => m.group(0))
      .toList();
  if (originalNumbers.length != renderedNumbers.length) return null;
  for (var i = 0; i < originalNumbers.length; i++) {
    if (originalNumbers[i] != renderedNumbers[i]) return null;
  }
  var cursor = 0;
  for (final match in RegExp(
    r"[A-Za-z][A-Za-z0-9]*(?:[-'][A-Za-z0-9]+)*",
  ).allMatches(raw)) {
    final token = match.group(0)!;
    final found = RegExp(
      '\\b${RegExp.escape(token)}\\b',
    ).firstMatch(candidate.substring(cursor));
    if (found == null) return null;
    cursor += found.end;
  }
  return candidate.trim();
}

/// Display never becomes action/field input. No guessed letter substitutions.
String transcriptForDisplay(
  String raw,
  AppLanguage language, {
  String? rendering,
  bool complete = false,
  bool interim = false,
}) {
  if (!needsRomanTranscript(raw, language)) return raw;
  final checked = validatedRomanTranscript(raw, rendering);
  if (checked != null) return checked;
  if (interim) return 'Sun raha hoon…';
  return complete
      ? 'Roman Urdu matn dastiyab nahi. Asal paigham mehfooz hai.'
      : 'Awaz ka paigham mil gaya. Roman Urdu matn ka intezar hai.';
}
