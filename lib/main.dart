import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/config/env.dart';
import 'core/config/prefs_provider.dart';
import 'shared/widgets/error_boundary.dart';

void main() {
  // Zone 기반 비동기 에러 캐치 — runZonedGuarded 안에서 ensureInitialized해야
  // Flutter 바인딩이 같은 Zone에 있어 Zone mismatch가 발생하지 않음
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1) 환경변수 로드
    await dotenv.load(fileName: '.env');

    // 2) Sentry 초기화 — appRunner 없이 사용해야 Zone mismatch 방지
    await SentryFlutter.init((options) {
      options.dsn = Env.sentryDsn;
      options.tracesSampleRate = 0.2;
    });

    // 3) Flutter 프레임워크 에러 → Sentry
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      Sentry.captureException(details.exception, stackTrace: details.stack);
    };

    // 4) 플랫폼 레이어 에러 → Sentry (isolate 외부 크래시 포함)
    PlatformDispatcher.instance.onError = (error, stack) {
      Sentry.captureException(error, stackTrace: stack);
      return true;
    };

    // 5) 위젯 빌드 실패 시 기본 빨간 화면 대신 친절한 UI
    setupGlobalErrorWidget();

    // 6) Supabase 초기화
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );

    // 7) 카카오 SDK 초기화 — 두 키를 동시에 넘겨야 SDK 내부에서 플랫폼별로 올바르게 선택됨
    KakaoSdk.init(
      nativeAppKey: Env.kakaoNativeKey,
      javaScriptAppKey: Env.kakaoJsKey,
    );

    // 8) SharedPreferences 초기화 — 글씨 크기·코치마크 설정 영속화
    final prefs = await SharedPreferences.getInstance();

    runApp(ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const MomPillApp(),
    ));
  }, (error, stack) {
    // Zone 내 잡히지 않은 비동기 에러 — Sentry 초기화 이후에만 전송 가능
    try {
      Sentry.captureException(error, stackTrace: stack);
    } catch (_) {}
  });
}
