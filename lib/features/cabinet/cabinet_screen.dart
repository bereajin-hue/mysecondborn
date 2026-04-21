import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_provider.dart';
import '../../features/scan/scan_provider.dart';
import '../../shared/theme/app_theme.dart';

class CabinetScreen extends ConsumerWidget {
  const CabinetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final userId = user?.id ?? '';

    if (userId.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(title: const Text('내 영양제')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final cabinetAsync = ref.watch(cabinetProvider(userId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('내 영양제')),
      body: cabinetAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
        error: (_, __) => const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              '잠깐 문제가 생겼어요. 다시 시도해주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Color(0xFF888888)),
            ),
          ),
        ),
        data: (items) => items.isEmpty
            ? _buildEmpty(context)
            : _buildList(context, ref, items, userId),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt_rounded,
              size: 96,
              color: Color(0xFFDDDDDD),
            ),
            const SizedBox(height: 28),
            const Text(
              '아직 저장된 영양제가 없어요',
              style: TextStyle(fontSize: 20, color: Color(0xFF888888)),
            ),
            const SizedBox(height: 12),
            const Text(
              '홈에서 사진 찍어보세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 17, color: Color(0xFFAAAAAA), height: 1.6),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.primaryColor, width: 2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.camera_alt_rounded,
                    color: AppTheme.primaryColor),
                label: const Text(
                  '사진 찍으러 가기',
                  style: TextStyle(
                      fontSize: 18,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> items,
    String userId,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _CabinetCard(item: items[index], userId: userId);
      },
    );
  }
}

class _CabinetCard extends ConsumerWidget {
  const _CabinetCard({required this.item, required this.userId});

  final Map<String, dynamic> item;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = item['image_url'] as String?;
    final productName = item['product_name'] as String;
    final addedAtStr = item['added_at'] as String?;
    final cabinetId = item['cabinet_id'] as String;
    final scanId = item['scan_id'] as String?;

    String dateLabel = '';
    if (addedAtStr != null) {
      final dt = DateTime.tryParse(addedAtStr)?.toLocal();
      if (dt != null) {
        dateLabel = '${dt.year}년 ${dt.month}월 ${dt.day}일 저장';
      }
    }

    return InkWell(
      onTap: scanId != null ? () => context.push('/result/$scanId') : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 제품 이미지 — CachedNetworkImage로 로딩 placeholder 제공
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 72,
                        height: 72,
                        color: const Color(0xFFF4F4F4),
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primaryColor),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),
            ),
            const SizedBox(width: 16),
            // 제품명 + 날짜
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF222222),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (dateLabel.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF999999)),
                    ),
                  ],
                ],
              ),
            ),
            // 삭제 버튼 (스와이프 없이 명시적 아이콘)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFCCCCCC), size: 28),
              tooltip: '삭제',
              onPressed: () {
                if (!kIsWeb) HapticFeedback.mediumImpact();
                _confirmDelete(context, ref, cabinetId, productName);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
        width: 72,
        height: 72,
        color: const Color(0xFFF4F4F4),
        child: const Icon(Icons.medication_rounded,
            size: 36, color: Color(0xFFCCCCCC)),
      );

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String cabinetId,
    String productName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('영양제 삭제',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        content: Text(
          '"$productName"을(를)\n내 영양제에서 삭제할까요?',
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소',
                style: TextStyle(fontSize: 16, color: Color(0xFF888888))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제',
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(scanRepositoryProvider).deleteFromCabinet(cabinetId);
      ref.invalidate(cabinetProvider(userId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('삭제했어요.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('잠깐 문제가 생겼어요. 다시 시도해주세요.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
