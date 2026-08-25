class ProjectModel {
  final int? id;
  final String url;
  final String armurl;
  final String schemaName;
  final String caption;
  final String logourl;
  final String color;

  const ProjectModel({
    this.id,
    required this.url,
    required this.armurl,
    required this.schemaName,
    this.caption = '',
    this.logourl = '',
    this.color = '',
  });

  ProjectModel copyWith({
    int? id,
    String? url,
    String? armurl,
    String? schemaName,
    String? caption,
    String? logourl,
    String? color,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      url: url ?? this.url,
      armurl: armurl ?? this.armurl,
      schemaName: schemaName ?? this.schemaName,
      caption: caption ?? this.caption,
      logourl: logourl ?? this.logourl,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'url': url.trim(),
    'armurl': armurl.trim(),
    'schema_name': schemaName.trim(),
    'caption': caption.trim(),
    'logourl': logourl.trim(),
    'color': color.trim(),
  };

  factory ProjectModel.fromMap(Map<String, dynamic> map) => ProjectModel(
    id: map['id'] as int?,
    url: map['url'] as String,
    armurl: map['armurl'] as String,
    schemaName: map['schema_name'] as String,
    caption: (map['caption'] as String?) ?? '',
    logourl: (map['logourl'] as String?) ?? '',
    color: (map['color'] as String?) ?? '',
  );

  bool isDuplicateOf(ProjectModel other) {
    return id == other.id &&
        url.trim().toLowerCase() == other.url.trim().toLowerCase() &&
        armurl.trim().toLowerCase() == other.armurl.trim().toLowerCase() &&
        schemaName.trim().toLowerCase() ==
            other.schemaName.trim().toLowerCase() &&
        caption.trim().toLowerCase() == other.caption.trim().toLowerCase() &&
        logourl.trim().toLowerCase() == other.logourl.trim().toLowerCase() &&
        color.trim().toLowerCase() == other.color.trim().toLowerCase();
  }

  @override
  String toString() =>
      'ProjectModel(id: $id, schemaName: $schemaName, url: $url, armurl: $armurl, caption: $caption, logourl: $logourl, color: $color)';
}
