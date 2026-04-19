import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) 환경변수 로드 — 이후 모든 SDK가 Env.*를 참조하므로 반드시 먼저 실행
  await dotenv.load(fileName: '.env');

  // 2) Sentry 초기화 — runApp을 감싸서 Flutter 프레임워크 에러까지 수집
  await SentryFlutter.init(
    (options) {
      options.dsn = Env.sentryDsn;
      options.tracesSampleRate = 0.2;
    },
    appRunner: () async {
      // 3) Supabase 초기화
      await Supabase.initialize(
        url: Env.supabaseUrl,
        anonKey: Env.supabaseAnonKey,
      );

      // 4) 카카오 SDK 초기화 — 인증 기능이 앱 전반에서 사용되므로 여기서 등록
      KakaoSdk.init(nativeAppKey: Env.kakaoNativeKey);

      runApp(const ProviderScope(child: MomPillApp()));
    },
  );
}
