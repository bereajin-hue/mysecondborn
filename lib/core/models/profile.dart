class Profile {
  final String id;
  final String? kakaoNickname;
  final String? avatarUrl;
  final DateTime createdAt;

  const Profile({
    required this.id,
    this.kakaoNickname,
    this.avatarUrl,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        kakaoNickname: json['kakao_nickname'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kakao_nickname': kakaoNickname,
        'avatar_url': avatarUrl,
        'created_at': createdAt.toIso8601String(),
      };
}
