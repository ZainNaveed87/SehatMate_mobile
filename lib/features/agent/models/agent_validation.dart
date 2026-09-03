bool isSafeAgentIdentifier(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.length > 128) return false;
  return RegExp(r'^[A-Za-z0-9._:-]+$').hasMatch(trimmed);
}
