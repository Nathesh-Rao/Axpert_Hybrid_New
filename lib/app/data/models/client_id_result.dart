class ClientIdResult {
  final String projectName;
  final String webUrl;
  final String armUrl;

  const ClientIdResult({
    required this.projectName,
    required this.webUrl,
    required this.armUrl,
  });

  factory ClientIdResult.fromJson(Map<String, dynamic> json) {
    // Drill into: result[0].result.row[0]
    final row = json['result'][0]['result']['row'][0];
    return ClientIdResult(
      projectName: (row['projectname'] as String).trim(),
      webUrl: (row['web_url'] as String).trim(),
      armUrl: (row['arm_url'] as String).trim(),
    );
  }
}
