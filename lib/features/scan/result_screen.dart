import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/auth/auth_provider.dart';
import '../../shared/theme/app_theme.dart';
import 'scan_provider.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key, required this.scanId});

  final String scanId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanAsync = ref.watch(scanStreamProvider(scanId));
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('분석 결과'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: '뒤로',
          onPressed: () => context.pop(),
        ),
      ),
      body: scanAsync.when(
        loading: _buildLoading,
        error: (_, __) => _buildError(context, '잠깐 문제가 생겼어요. 다시 시도해주세요.'),
        data: (scan) {
          if (scan == null) return _buildLoading();
          final gemini = scan['gemini_response'] as Map<String, dynamic>?;
          if (gemini == null) return _buildLoading(); // Edge Function 아직 처리 중
          if (gemini['error'] != null) {
            return _buildError(context, gemini['error'] as String);
          }
          return _buildResult(context, ref, scan, gemini, user?.id ?? '');
        },
      ),
    );
  }

  Widget _buildLoading() => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 5),
            ),
            SizedBox(height: 32),
            Text(
              '엄마가 찍으신 영양제를\n분석 중이에요...',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, color: Color(0xFF555555), height: 1.5),
            ),
            SizedBox(height: 12),
            Text('잠깐만 기다려 주세요 🙂',
                style: TextStyle(fontSize: 16, color: Color(0xFF999999))),
          ],
        ),
      );

  Widget _buildError(BuildContext context, String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sentiment_dissatisfied_rounded,
                  size: 72, color: Color(0xFFCCCCCC)),
              const SizedBox(height: 24),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18, color: Color(0xFF555555), height: 1.5),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => context.pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                  label: const Text('다시 찍어볼게요',
                      style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildResult(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> scan,
    Map<String, dynamic> gemini,
    String userId,
  ) {
    final imageUrl = scan['raw_image_url'] as String?;
    final productId = scan['product_id'] as String?;

    final productName = gemini['product_name'] as String? ?? '알 수 없는 제품';
    final brand = gemini['brand'] as String?;
    final confidence = ((gemini['confidence'] as num?) ?? 0).toDouble();
    final summary = gemini['readable_summary'] as String? ?? '';
    final ingredients = (gemini['main_ingredients'] as List<dynamic>?) ?? [];
    final keyBenefits = (gemini['key_benefits'] as List<dynamic>?) ?? [];
    final warnings = (gemini['warnings'] as List<dynamic>?) ?? [];
    final goodWith = (gemini['good_with'] as List<dynamic>?) ?? [];
    final avoidWith = (gemini['avoid_with'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 상단 제품 이미지 ────────────────────────────────────
          if (imageUrl != null)
            SizedBox(
              width: double.infinity,
              height: 220,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFF0F0F0),
                  child: const Icon(Icons.image_not_supported_rounded,
                      size: 64, color: Color(0xFFCCCCCC)),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 제품명 + 브랜드 ──────────────────────────────
                Text(
                  productName,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF222222)),
                ),
                if (brand != null) ...[
                  const SizedBox(height: 4),
                  Text(brand,
                      style: const TextStyle(
                          fontSize: 16, color: Color(0xFF888888))),
                ],
                const SizedBox(height: 10),

                // ── 신뢰도 배지 ──────────────────────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: confidence >= 0.7
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '분석 신뢰도 ${(confidence * 100).round()}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: confidence >= 0.7
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFE65100),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── 70대 어머니 3줄 설명 ────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.2)),
                  ),
                  child: Text(
                    summary,
                    style: const TextStyle(
                        fontSize: 17,
                        color: Color(0xFF333333),
                        height: 1.7),
                  ),
                ),

                // ── 주요 성분 카드 (최대 3개) ─────────────────────
                if (ingredients.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  const Text('주요 성분',
                      style: TextStyle(
                          fontSize: 19, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...ingredients.take(3).map((e) {
                    final m = e as Map<String, dynamic>;
                    final name = m['name'] as String? ?? '';
                    final amount = m['amount'] as String?;
                    final daily = m['daily_percent'] as String?;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(name,
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF333333))),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (amount != null)
                                Text(amount,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF555555))),
                              if (daily != null)
                                Text(
                                  '일일권장량 $daily',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.primaryColor),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                // ── 이런 점에 좋아요 ─────────────────────────────
                if (keyBenefits.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  const Text('이런 점에 좋아요',
                      style: TextStyle(
                          fontSize: 19, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...keyBenefits.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('✓  ',
                                style: TextStyle(
                                    fontSize: 17,
                                    color: Color(0xFF22AA44))),
                            Expanded(
                              child: Text(e as String,
                                  style: const TextStyle(
                                      fontSize: 17,
                                      color: Color(0xFF444444))),
                            ),
                          ],
                        ),
                      )),
                ],

                // ── 함께 먹으면 도움이 될 수 있어요 (초록 박스) ──
                if (goodWith.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF9F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFB2DFDB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💚 함께 먹으면 도움이 될 수 있어요',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B6B3A))),
                        const SizedBox(height: 8),
                        ...goodWith.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text('• $e',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF2D5A3D),
                                      height: 1.5)),
                            )),
                      ],
                    ),
                  ),
                ],

                // ── 함께 드실 때 주의가 필요해요 (노란 박스) ────────
                if (avoidWith.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFE082)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('⚠️ 함께 드실 때 주의가 필요해요',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7B5800))),
                        const SizedBox(height: 4),
                        const Text('궁금하신 점은 약사나 전문가와 상담하세요.',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF9E7B00))),
                        const SizedBox(height: 10),
                        ...avoidWith.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text('• $e',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF5D4200),
                                      height: 1.5)),
                            )),
                      ],
                    ),
                  ),
                ],

                // ── 주의사항 (빨간 박스) ─────────────────────────
                if (warnings.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFCCCC)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('⚠️ 주의사항',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFCC2200))),
                        const SizedBox(height: 8),
                        ...warnings.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('• $e',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF883300),
                                      height: 1.4)),
                            )),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 36),

                // ── 하단 버튼 2개 ────────────────────────────────
                // ① 쿠팡 가격 보기 (주황색)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => _openCoupang(context, productName),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4500),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.shopping_cart_rounded,
                        color: Colors.white, size: 22),
                    label: const Text(
                      '쿠팡에서 가격 보기',
                      style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ② 내 영양제에 저장 (흰색 테두리)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: productId != null
                        ? () => _saveToMyCabinet(context, ref, userId, productId)
                        : null,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: AppTheme.primaryColor, width: 2),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.bookmark_add_rounded,
                        color: AppTheme.primaryColor, size: 22),
                    label: const Text(
                      '내 영양제에 저장',
                      style: TextStyle(
                          fontSize: 18,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    '쿠팡 파트너스 활동의 일환으로, 수수료를 받을 수 있습니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCoupang(BuildContext context, String keyword) async {
    final uri = Uri.parse(
        'https://www.coupang.com/np/search?q=${Uri.encodeComponent(keyword)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('쿠팡을 열 수 없어요. 브라우저를 확인해주세요.')),
        );
      }
    }
  }

  Future<void> _saveToMyCabinet(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String productId,
  ) async {
    try {
      await ref.read(scanRepositoryProvider).saveToMyCabinet(userId, productId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('내 영양제에 저장했어요! 💊'),
            backgroundColor: Color(0xFF22AA44),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
