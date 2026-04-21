import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// main.dart에서 실제 인스턴스로 override
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPrefsProvider는 main.dart에서 override 필요');
});

enum FontSizeLevel { small, normal, large, xlarge }

extension FontSizeLevelExt on FontSizeLevel {
  double get scale => switch (this) {
        FontSizeLevel.small => 0.85,
        FontSizeLevel.normal => 1.0,
        FontSizeLevel.large => 1.15,
        FontSizeLevel.xlarge => 1.30,
      };

  String get label => switch (this) {
        FontSizeLevel.small => '작게',
        FontSizeLevel.normal => '보통',
        FontSizeLevel.large => '크게',
        FontSizeLevel.xlarge => '아주 크게',
      };
}

const _kFontSizeKey = 'font_size_level';
const _kCoachMarkKey = 'coach_mark_seen';

class FontSizeNotifier extends StateNotifier<FontSizeLevel> {
  FontSizeNotifier(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;

  static FontSizeLevel _load(SharedPreferences prefs) {
    final saved = prefs.getString(_kFontSizeKey);
    return FontSizeLevel.values.firstWhere(
      (e) => e.name == saved,
      orElse: () => FontSizeLevel.normal,
    );
  }

  void set(FontSizeLevel level) {
    state = level;
    _prefs.setString(_kFontSizeKey, level.name);
  }
}

final fontSizeProvider =
    StateNotifierProvider<FontSizeNotifier, FontSizeLevel>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return FontSizeNotifier(prefs);
});

class _CoachMarkNotifier extends StateNotifier<bool> {
  _CoachMarkNotifier(this._prefs)
      : super(_prefs.getBool(_kCoachMarkKey) ?? false);

  final SharedPreferences _prefs;

  void markSeen() {
    state = true;
    _prefs.setBool(_kCoachMarkKey, true);
  }
}

// true면 이미 코치마크를 본 것
final coachMarkSeenProvider =
    StateNotifierProvider<_CoachMarkNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return _CoachMarkNotifier(prefs);
});
