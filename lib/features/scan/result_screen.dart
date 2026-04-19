import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/theme/app_theme.dart';
import 'scan_provider.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key, required this.scanId});

  final String scanId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(scanResultProvider(scanId));

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
      body: result.when(
        loading: _buildLoading,
        error: (e, _) => _buildError(context, '잠깐 문제가 생겼어요. 다시 시도해주세요.'),
        data: (data) {
          if (data == null) return _buildLoading();
          if (data['error'] != null) {
            return _buildError(context, data['error'] as String);
          }
          return _buildResult(context, data);
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
              child: CircularProgressIndicator(
                  color: AppTheme.primaryColor, strokeWidth: 5),
            ),
            SizedBox(height: 32),
            Text('열심히 분석 중이에요...',
                style: TextStyle(fontSize: 20, color: Color(0xFF555555))),
            SizedBox(height: 12),
            Text('잠깐만 기다려 주세요',
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
                  size: 64, color: Color(0xFFCCCCCC)),
              const SizedBox(height: 24),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18, color: Color(0xFF555555), height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => context.pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('다시 시도할게요',
                      style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildResult(BuildContext context, Map<String, dynamic> data) {
    final productName = data['product_name'] as String? ?? '알 수 없는 제품';
    final confidence = ((data['confidence'] as num?) ?? 0).toDouble();
    final summary = data['readable_summary'] as String? ?? '';
    final ingredients = (data['main_ingredients'] as List<dynamic>?) ?? [];
    final warnings = (data['warnings'] as List<dynamic>?) ?? [];
    final recommendedFor = (data['recommended_for'] as List<dynamic>?) ?? [];
    final coupangKeyword =
        data['coupang_search_keyword'] as String? ?? productName;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제품명
          Text(
            productName,
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222222)),
          ),
          const SizedBox(height: 8),

          // 신뢰도
          Row(
            children: [
              const Text('분석 신뢰도  ',
                  style: TextStyle(fontSize: 15, color: Color(0xFF888888))),
              Text(
                '${(confidence * 100).round()}%',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: confidence >= 0.7
                      ? const Color(0xFF22AA44)
                      : const Color(0xFFFF8800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 한 줄 요약
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              summary,
              style: const TextStyle(
                  fontSize: 17, color: Color(0xFF333333), height: 1.6),
            ),
          ),

          // 주요 성분
          if (ingredients.isNotEmpty) ...[
            const SizedBox(height: 28),
            const Text('주요 성분',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...ingredients.map((e) {
              final m = e as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(
                            fontSize: 17, color: AppTheme.primaryColor)),
                    Expanded(
                      child: Text(
                        '${m['name']} — ${m['benefit']}',
                        style: const TextStyle(
                            fontSize: 17,
                            color: Color(0xFF444444),
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          // 이런 분께 좋아요
          if (recommendedFor.isNotEmpty) ...[
            const SizedBox(height: 28),
            const Text('이런 분께 좋아요',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...recommendedFor.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('✓ ',
                          style: TextStyle(
                              fontSize: 17, color: Color(0xFF22AA44))),
                      Expanded(
                        child: Text(e as String,
                            style: const TextStyle(
                                fontSize: 17, color: Color(0xFF444444))),
                      ),
                    ],
                  ),
                )),
          ],

          // 주의사항
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 28),
            const Text('주의사항',
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFCC4400))),
            const SizedBox(height: 12),
            ...warnings.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('⚠️ ', style: TextStyle(fontSize: 16)),
                      Expanded(
                        child: Text(e as String,
                            style: const TextStyle(
                                fontSize: 17,
                                color: Color(0xFF444444),
                                height: 1.4)),
                      ),
                    ],
                  ),
                )),
          ],

          const SizedBox(height: 36),

          // 쿠팡 최저가 버튼
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => _openCoupang(context, coupangKeyword),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4500),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.shopping_cart_rounded,
                  color: Colors.white, size: 22),
              label: const Text(
                '쿠팡에서 최저가 보기',
                style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              '쿠팡 파트너스 활동의 일환으로, 수수료를 받을 수 있습니다',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)),
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
          const SnackBar(content: Text('쿠팡 앱을 열 수 없어요. 브라우저를 확인해주세요.')),
        );
      }
    }
  }
}
