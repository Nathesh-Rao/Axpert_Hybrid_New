// ── QR payload model ──────────────────────────────────────────────────
import 'dart:convert';

class QrPayload {
  final String pUrl; // p_url  → project url
  final String armUrl; // arm_url
  final String spath; // spath
  final String pName; // pname  → schemaName + caption

  const QrPayload({
    required this.pUrl,
    required this.armUrl,
    required this.spath,
    required this.pName,
  });

  /// Returns null if any required field is missing or empty
  static QrPayload? tryParse(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;

      final pUrl = (map['p_url'] as String?)?.trim() ?? '';
      final armUrl = (map['arm_url'] as String?)?.trim() ?? '';
      final spath = (map['spath'] as String?)?.trim() ?? '';
      final pName = (map['pname'] as String?)?.trim() ?? '';

      if (pUrl.isEmpty || pName.isEmpty) return null;

      return QrPayload(pUrl: pUrl, armUrl: armUrl, spath: spath, pName: pName);
    } catch (_) {
      return null;
    }
  }
}
