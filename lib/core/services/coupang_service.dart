import 'package:url_launcher/url_launcher.dart';

class CoupangService {
  final String _trackingId;

  const CoupangService(this._trackingId);

  // 제품명 → 쿠팡 검색 URL (트래킹 포함)
  String buildSearchUrl(String productName) {
    final cleaned = productName
        .replaceAll(RegExp(r'[^\w\s가-힣ㄱ-ㅎㅏ-ㅣ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final encoded = Uri.encodeComponent(cleaned);
    return 'https://www.coupang.com/np/search?q=$encoded&channel=user&lptag=$_trackingId';
  }

  // 딥링크 실행 → 쿠팡 앱 없으면 웹 URL로 자동 폴백
  Future<void> openProductSearch(String productName) async {
    final webUrl = buildSearchUrl(productName);

    // 모바일 딥링크 먼저 시도
    final deepLink = Uri.parse(
      'coupang://search?q=${Uri.encodeComponent(productName.replaceAll(RegExp(r'[^\w\s가-힣ㄱ-ㅎㅏ-ㅣ]'), ' ').trim())}',
    );

    if (await canLaunchUrl(deepLink)) {
      await launchUrl(deepLink);
    } else {
      // 앱 없거나 웹 환경 → 웹 쿠팡으로 폴백
      await launchUrl(
        Uri.parse(webUrl),
        mode: LaunchMode.externalApplication,
      );
    }
  }
}
