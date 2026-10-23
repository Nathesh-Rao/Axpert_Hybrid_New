/// Match whole names/captions anywhere in server prose, without guessing.
String? matchOfflineErrorField(
  String message,
  List<Map<String, dynamic>> fields,
) {
  String normalize(String text) =>
      text.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  final text = normalize(message);
  final matches = <({String name, int start, int end})>[];
  for (final field in fields) {
    if (field['hidden'] == 'T') continue;
    final name = field['fld_name']?.toString() ?? '';
    if (name.isEmpty) continue;
    for (final candidate in [name, field['fld_caption']?.toString() ?? '']) {
      final label = normalize(candidate);
      if (label.isEmpty) continue;
      for (final match in RegExp(
        '(^|[^a-z0-9_])${RegExp.escape(label)}(?=\$|[^a-z0-9_])',
        unicode: true,
      ).allMatches(text)) {
        matches.add((
          name: name,
          start: match.end - label.length,
          end: match.end,
        ));
      }
    }
  }
  if (matches.isEmpty) return null;
  // Prefer "Item Code" over a shorter "Code" inside that same phrase,
  // but do not guess when two distinct fields are mentioned in the message.
  final best = matches
      .where(
        (match) => !matches.any(
          (other) =>
              other.start <= match.start &&
              other.end >= match.end &&
              other.end - other.start > match.end - match.start,
        ),
      )
      .map((m) => m.name)
      .toSet();
  return best.length == 1 ? best.single : null;
}
