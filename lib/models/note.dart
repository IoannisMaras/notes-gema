class Note {
  final String id;
  String title;
  String content;
  DateTime updatedAt;
  List<String> imagePaths;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
    this.imagePaths = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'updatedAt': updatedAt.toIso8601String(),
    'imagePaths': imagePaths,
  };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'],
    title: json['title'],
    content: json['content'],
    updatedAt: DateTime.parse(json['updatedAt']),
    imagePaths: List<String>.from(json['imagePaths'] ?? []),
  );
}
