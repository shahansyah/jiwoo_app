import 'dart:convert';

class ActivityItem {
  final String id;
  final String title;
  final String category;
  final String notes;
  final bool isCompleted;
  final DateTime createdAt;

  ActivityItem({
    required this.id,
    required this.title,
    required this.category,
    required this.notes,
    this.isCompleted = false,
    required this.createdAt,
  });

  ActivityItem copyWith({
    String? id,
    String? title,
    String? category,
    String? notes,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return ActivityItem(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'notes': notes,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ActivityItem.fromMap(Map<String, dynamic> map) {
    return ActivityItem(
      id: map['id'] as String,
      title: map['title'] as String,
      category: map['category'] as String,
      notes: map['notes'] as String? ?? '',
      isCompleted: map['isCompleted'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ActivityItem.fromJson(String source) =>
      ActivityItem.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
