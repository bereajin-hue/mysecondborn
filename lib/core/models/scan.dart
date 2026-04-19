// geminiResponse는 jsonb 원본을 그대로 보존 — 프롬프트 버전 업 시 재파싱 가능하도록
class Scan {
  final String id;
  final String userId;
  final String? productId;
  final String? rawImageUrl;
  final Map<String, dynamic>? geminiResponse;
  final DateTime createdAt;

  const Scan({
    required this.id,
    required this.userId,
    this.productId,
    this.rawImageUrl,
    this.geminiResponse,
    required this.createdAt,
  });

  factory Scan.fromJson(Map<String, dynamic> json) => Scan(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        productId: json['product_id'] as String?,
        rawImageUrl: json['raw_image_url'] as String?,
        geminiResponse: json['gemini_response'] as Map<String, dynamic>?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'product_id': productId,
        'raw_image_url': rawImageUrl,
        'gemini_response': geminiResponse,
        'created_at': createdAt.toIso8601String(),
      };
}
