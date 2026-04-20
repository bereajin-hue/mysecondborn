import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class CoupangService {
  // HMAC 서명은 서버에서만 해야 하므로 Edge Function 경유
  Future<String> getAffiliateUrl(String productName) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'coupang-links',
        body: {'product_name': productName},
      );
      final url = response.data['url'] as String?;
      if (url != null && url.isNotEmpty) return url;
    } catch (_) {}
    // Edge Function 장애 시 클라이언트 직접 검색으로 폴백
    final q = Uri.encodeComponent(productName);
    return 'https://www.coupang.com/np/search?q=$q&channel=user';
  }

  Future<void> openProductSearch(String productName) async {
    final affiliateUrl = await getAffiliateUrl(productName);

    // 쿠팡 앱 딥링크 먼저 시도 (모바일 전용, 웹에선 canLaunchUrl = false)
    final appDeepLink = Uri.parse(
      'coupang://search?q=${Uri.encodeComponent(productName.replaceAll(RegExp(r'[^\w\s가-힣ㄱ-ㅎㅏ-ㅣ]'), ' ').trim())}',
    );

    if (await canLaunchUrl(appDeepLink)) {
      await launchUrl(appDeepLink);
    } else {
      await launchUrl(Uri.parse(affiliateUrl), mode: LaunchMode.externalApplication);
    }
  }
}
