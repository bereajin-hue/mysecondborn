class CabinetItem {
  final String id;
  final String userId;
  final String productId;
  final String? note;
  final DateTime addedAt;

  const CabinetItem({
    required this.id,
    required this.userId,
    required this.productId,
    this.note,
    required this.addedAt,
  });

  factory CabinetItem.fromJson(Map<String, dynamic> json) => CabinetItem(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        productId: json['product_id'] as String,
        note: json['note'] as String?,
        addedAt: DateTime.parse(json['added_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'product_id': productId,
        'note': note,
        'added_at': addedAt.toIso8601String(),
      };
}
