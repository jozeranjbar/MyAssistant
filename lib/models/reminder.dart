class Reminder {
  final int id; // برای شناسه اعلان محلی هم استفاده می‌شود
  String title;
  String note;
  DateTime dateTime;
  bool repeatDaily;
  bool isActive;

  Reminder({
    required this.id,
    required this.title,
    this.note = '',
    required this.dateTime,
    this.repeatDaily = false,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'note': note,
        'dateTime': dateTime.toIso8601String(),
        'repeatDaily': repeatDaily,
        'isActive': isActive,
      };

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
        id: json['id'],
        title: json['title'],
        note: json['note'] ?? '',
        dateTime: DateTime.parse(json['dateTime']),
        repeatDaily: json['repeatDaily'] ?? false,
        isActive: json['isActive'] ?? true,
      );
}
