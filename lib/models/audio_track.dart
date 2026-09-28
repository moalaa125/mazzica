class AudioTrack {
  final String id;
  final String title;
  final String fileName;
  final DateTime addedAt;

  const AudioTrack({
    required this.id,
    required this.title,
    required this.fileName,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'fileName': fileName,
        'addedAt': addedAt.toIso8601String(),
      };

  factory AudioTrack.fromJson(Map<String, dynamic> json) => AudioTrack(
        id: json['id'] as String,
        title: json['title'] as String,
        fileName: json['fileName'] as String,
        addedAt: DateTime.parse(json['addedAt'] as String),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AudioTrack && other.id == id;

  @override
  int get hashCode => id.hashCode;
}