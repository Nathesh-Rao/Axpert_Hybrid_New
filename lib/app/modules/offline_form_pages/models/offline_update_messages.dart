/// Existing callers may request friendly text; refresh lookup details can keep
/// the server message verbatim, including SQL codes, quotes and line breaks.
String friendlyLookupFailure({
  required String lookup,
  required String form,
  String? error,
  bool preserveOriginal = false,
}) {
  if (preserveOriginal && error != null && error.trim().isNotEmpty) {
    return error;
  }
  final text = (error ?? '')
      .replaceFirst(RegExp(r'^(Exception|Bad state|StateError):\s*'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final lower = text.toLowerCase();
  final retry = 'Please try refreshing $form again.';
  final label = lookup.toLowerCase().endsWith('lookup data')
      ? lookup
      : '$lookup lookup data';
  if (lower.contains('session') ||
      lower.contains('unauthoriz') ||
      lower.contains('token expired')) {
    return '$label couldn’t be updated because your session expired. Sign in again, then refresh $form.';
  }
  if (lower.contains('timeout') || lower.contains('timed out')) {
    return 'The server took too long to respond while downloading $label. $retry';
  }
  if (lower.contains('connectivity') ||
      lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('no internet')) {
    return '$label couldn’t be downloaded. Check your internet connection, then refresh $form.';
  }
  if (lower.contains('sqlite') ||
      lower.contains('databaseexception') ||
      lower.contains('could not store')) {
    return '$label couldn’t be saved on this device. $retry';
  }
  if (text.isEmpty ||
      lower.contains('no lookup data returned') ||
      lower.contains('no response') ||
      lower.contains('invalid response') ||
      lower.contains('missing lookup')) {
    return '$label couldn’t be downloaded because it wasn’t returned by the server. $retry';
  }
  final technical =
      text.length > 350 ||
      RegExp(
        r'(__[A-Z_0-9]+__|https?://|\b[0-9]{5}:|\bSELECT\b|\bINSERT\b|\bSQLSTATE\b|\bvarchar\b|\bcharacter varying\b|\bTypeError\b|\bFormatException\b|\bStackTrace\b|\bHTTP\s*[45][0-9]{2}\b|<[^>]+>|[{}])',
        caseSensitive: false,
      ).hasMatch(text);
  if (technical)
    return '$label couldn’t be updated because the server could not complete the request. $retry';
  // Preserve clear server explanations instead of replacing them with a generic error.
  return text;
}

/// Compact the display only; the original diagnostic remains in the stored
/// refresh report. Keep real line breaks and all non-empty error text.
String lookupErrorDisplayText(String message) => message
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .split('\n')
    .where((line) => line.trim().isNotEmpty)
    .join('\n')
    .trim();

String offlineLookupCaption(Map<String, dynamic> page, String datasource) {
  if (datasource.isEmpty) return 'Lookup data';
  final fields = page['fields'];
  if (fields is List) {
    for (final field in fields.whereType<Map>()) {
      if (field['datasource']?.toString() == datasource) {
        final caption = field['fld_caption']?.toString().trim() ?? '';
        if (caption.isNotEmpty) return caption;
      }
    }
  }
  return datasource; // Schema caption is preferred; retain the real identifier as fallback.
}
