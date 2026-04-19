import '../config/app_config.dart';

class UsageLimit {
  final String userId;
  final DateTime date;
  final int count;

  const UsageLimit({
    required this.userId,
    required this.date,
    required this.count,
  });

  // 일일 한도 초과 여부 — Gemini 호출 직전 반드시 이 값을 확인
  bool get isExhausted => count >= AppConfig.geminiDailyLimit;
  int get remaining => (AppConfig.geminiDailyLimit - count).clamp(0, AppConfig.geminiDailyLimit);

  factory UsageLimit.fromJson(Map<String, dynamic> json) => UsageLimit(
        userId: json['user_id'] as String,
        date: DateTime.parse(json['date'] as String),
        count: json['count'] as int,
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'date': date.toIso8601String().substring(0, 10),
        'count': count,
      };
}
