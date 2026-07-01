import 'dart:convert';

class Folder {
  Folder({
    required this.id,
    required this.name,
    required this.createdAt,
    List<String>? meetingIds,
  }) : meetingIds = meetingIds ?? [];

  final String id;
  final String name;
  final DateTime createdAt;
  final List<String> meetingIds;

  Folder copyWith({String? name, List<String>? meetingIds}) {
    return Folder(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      meetingIds: meetingIds ?? List.from(this.meetingIds),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'created_at': createdAt.toIso8601String(),
        'meeting_ids': meetingIds,
      };

  factory Folder.fromJson(Map<String, dynamic> json) => Folder(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        meetingIds: List<String>.from(json['meeting_ids'] as List? ?? []),
      );

  static List<Folder> listFromJson(String raw) {
    final list = jsonDecode(raw) as List;
    return list.map((e) => Folder.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String listToJson(List<Folder> folders) =>
      jsonEncode(folders.map((f) => f.toJson()).toList());
}
