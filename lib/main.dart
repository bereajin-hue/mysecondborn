import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) 환경변수 로드
  await dotenv.load(fileName: '.env');

  // 2) Sentry 초기화 — appRunner 없이 사용해야 Zone mismatch 방지
  await SentryFlutter.init((options) {
    options.dsn = Env.sentryDsn;
    options.tracesSampleRate = 0.2;
  });

  // 3) Supabase 초기화
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  // 4) 카카오 SDK 초기화
  KakaoSdk.init(nativeAppKey: Env.kakaoNativeKey);

  // 5) PostHog 초기화 — API 키 없으면 조용히 스킵
  final postHogKey = Env.postHogApiKey;
  if (postHogKey.isNotEmpty) {
    await Posthog().setup(
      postHogKey,
      options: PostHogConfig('https://app.posthog.com')
        ..captureApplicationLifecycleEvents = false
        ..debug = false,
    );
  }

  runApp(const ProviderScope(child: MomPillApp()));
}
