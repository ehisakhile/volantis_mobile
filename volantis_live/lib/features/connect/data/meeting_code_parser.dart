/// Extracts meeting ID from various input formats (code, URL, link)
/// Returns null if input doesn't match any known format
String? extractMeetingId(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  // Try URL parameter format: ?meeting=code or &meeting=code
  final urlMatch = RegExp(r'[?&]meeting=([^&]+)').firstMatch(trimmed);
  if (urlMatch != null) {
    final code = urlMatch.group(1);
    if (code != null && code.isNotEmpty) return code;
  }

  // Try /join/ path format: /join/code
  final joinMatch = RegExp(r'/([^/?]+)').firstMatch(trimmed);
  if (joinMatch != null) {
    final code = joinMatch.group(1);
    if (code != null && code.isNotEmpty) return code;
  }

  // Try connect.volantislive.com/code format
  final volantisMatch = RegExp(
    r'connect.volantislive\.com/([^/?]+)',
  ).firstMatch(trimmed);
  if (volantisMatch != null) {
    final code = volantisMatch.group(1);
    if (code != null && code.isNotEmpty && code != 'join') return code;
  }

  // Try raw code format: alphanumeric, 10-20 chars
  final codeMatch = RegExp(r'^[A-Za-z0-9]{6,}$').firstMatch(trimmed);
  if (codeMatch != null) return trimmed;

  return null;
}
