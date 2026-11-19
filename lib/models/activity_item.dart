import 'dart:convert';

class ActivityItem {
  final String id;
  final String title;
  final String category;
  final String notes;
  final bool isCompleted;
  final bool isPinned;
  final DateTime? deadline;
  final int focusMinutes;
  final DateTime createdAt;

  ActivityItem({
    required this.id,
    required this.title,
    required this.category,
    required this.notes,
    this.isCompleted = false,
    this.isPinned = false,
    this.deadline,
    this.focusMinutes = 0,
    required this.createdAt,
  });

  ActivityItem copyWith({
    String? id,
    String? title,
    String? category,
    String? notes,
    bool? isCompleted,
    bool? isPinned,
    DateTime? deadline,
    bool clearDeadline = false,
    int? focusMinutes,
    DateTime? createdAt,
  }) {
    return ActivityItem(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
      isPinned: isPinned ?? this.isPinned,
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      focusMinutes: focusMinutes ?? this.focusMinutes,
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
      'isPinned': isPinned,
      'deadline': deadline?.toIso8601String(),
      'focusMinutes': focusMinutes,
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
      isPinned: map['isPinned'] as bool? ?? false,
      deadline: map['deadline'] != null
          ? DateTime.tryParse(map['deadline'] as String)
          : null,
      focusMinutes: map['focusMinutes'] as int? ?? 0,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ActivityItem.fromJson(String source) =>
      ActivityItem.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
