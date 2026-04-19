// Gemini 프롬프트 출력 스키마와 1:1 대응 — 구조 변경 시 prompts/product_analysis.md도 함께 수정
class Ingredient {
  final String name;
  final String? amount;
  final double? dailyValuePercent;

  const Ingredient({
    required this.name,
    this.amount,
    this.dailyValuePercent,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
        name: json['name'] as String,
        amount: json['amount'] as String?,
        dailyValuePercent: (json['daily_value_percent'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
        'daily_value_percent': dailyValuePercent,
      };
}

class Product {
  final String id;
  final String name;
  final String? brand;
  final List<Ingredient> ingredients;
  final String? imageUrl;
  final String? coupangSearchUrl;
  final int hitCount;
  final DateTime createdAt;

  const Product({
    required this.id,
    required this.name,
    this.brand,
    required this.ingredients,
    this.imageUrl,
    this.coupangSearchUrl,
    required this.hitCount,
    required this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        name: json['name'] as String,
        brand: json['brand'] as String?,
        ingredients: (json['ingredients'] as List<dynamic>)
            .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
            .toList(),
        imageUrl: json['image_url'] as String?,
        coupangSearchUrl: json['coupang_search_url'] as String?,
        hitCount: json['hit_count'] as int,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'brand': brand,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'image_url': imageUrl,
        'coupang_search_url': coupangSearchUrl,
        'hit_count': hitCount,
        'created_at': createdAt.toIso8601String(),
      };
}
