import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import '../../shared/theme/app_theme.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(loginLoadingProvider);
    final errorMsg  = ref.watch(loginErrorProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // 앱 로고 + 설명
              const Text(
                'MomPill',
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '영양제 사기 전에\n사진 한 장 찍어보세요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, color: Color(0xFF555555), height: 1.5),
              ),

              const Spacer(flex: 2),

              // 에러 메시지 (있을 때만 표시)
              if (errorMsg != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEEEE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    errorMsg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Color(0xFFCC2200)),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 카카오 로그인 버튼 — 브랜드 가이드라인: #FEE500 배경, 검정 텍스트
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isLoading ? null : () => _onKakaoLogin(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEE500),
                    foregroundColor: const Color(0xFF191919),
                    disabledBackgroundColor: const Color(0xFFFEE500).withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Color(0xFF191919),
                          ),
                        )
                      : const Text(
                          '카카오로 3초 만에 시작',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                ),
              ),

              const SizedBox(height: 20),
              const Text(
                '광고 없이 무료로 쓰실 수 있어요',
                style: TextStyle(fontSize: 15, color: Color(0xFF888888)),
              ),

              const Spacer(),

              // 약관 — 체크박스 없이 텍스트 한 줄로 (시니어 UX: 복잡한 UI 제거)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  '시작하면 서비스 이용약관 및 개인정보 처리방침에\n동의하신 것으로 간주됩니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFFBBBBBB), height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onKakaoLogin(BuildContext context, WidgetRef ref) async {
    // 로딩 시작, 이전 에러 초기화
    ref.read(loginLoadingProvider.notifier).state = true;
    ref.read(loginErrorProvider.notifier).state   = null;

    try {
      await ref.read(authRepositoryProvider).signInWithKakao();
      // 성공 시 GoRouter refreshListenable이 auth 변화를 감지해 /로 자동 이동
    } on AuthException catch (e) {
      ref.read(loginErrorProvider.notifier).state = e.userMessage;
    } catch (_) {
      ref.read(loginErrorProvider.notifier).state = '잠깐 문제가 생겼어요. 다시 시도해주세요.';
    } finally {
      ref.read(loginLoadingProvider.notifier).state = false;
    }
  }
}
