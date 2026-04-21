import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/prefs_provider.dart';
import '../auth/auth_provider.dart';
import '../../shared/theme/app_theme.dart';
import 'scan_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _picker = ImagePicker();
  bool _showCoachMark = false;
  Timer? _coachTimer;

  @override
  void initState() {
    super.initState();
    // 첫 방문자에게만 코치마크 표시 — 5초 후 자동 소멸
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final seen = ref.read(coachMarkSeenProvider);
      if (!seen && mounted) {
        setState(() => _showCoachMark = true);
        _coachTimer = Timer(const Duration(seconds: 5), _dismissCoachMark);
      }
    });
  }

  @override
  void dispose() {
    _coachTimer?.cancel();
    super.dispose();
  }

  void _dismissCoachMark() {
    if (!mounted) return;
    setState(() => _showCoachMark = false);
    ref.read(coachMarkSeenProvider.notifier).markSeen();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final name = user?.userMetadata?['nickname'] as String? ?? '고객';
    final scanState = ref.watch(scanNotifierProvider);

    // 분석 완료 → 결과 화면으로, 에러 → SnackBar
    ref.listen(scanNotifierProvider, (prev, next) {
      if (next.scanId != null && prev?.scanId == null) {
        final id = next.scanId!;
        ref.read(scanNotifierProvider.notifier).reset();
        context.push('/result/$id');
      }
      if (next.error != null && prev?.error == null) {
        ref.read(scanNotifierProvider.notifier).reset();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: const Color(0xFFCC2200),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            title: Text('안녕하세요, $name님 👋'),
            centerTitle: false,
            actions: [
              // 촬영 도움말 아이콘
              IconButton(
                icon: const Icon(Icons.help_outline_rounded,
                    color: Color(0xFF888888), size: 26),
                tooltip: '촬영 도움말',
                onPressed: () => _showPhotoTipsDialog(context),
              ),
            ],
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '분석할 영양제를\n사진으로 찍어주세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 22, color: Color(0xFF555555), height: 1.5),
                ),
                const SizedBox(height: 56),
                GestureDetector(
                  onTap: scanState.isProcessing
                      ? null
                      : () {
                          if (!kIsWeb) HapticFeedback.mediumImpact();
                          _onCameraPressed(context, user?.id ?? '');
                        },
                  child: AnimatedOpacity(
                    opacity: scanState.isProcessing ? 0.5 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.35),
                            blurRadius: 28,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 88,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                const Text(
                  '버튼을 눌러 촬영하세요',
                  style: TextStyle(fontSize: 16, color: Color(0xFF999999)),
                ),
              ],
            ),
          ),
        ),

        // 분석 중 전체화면 오버레이 — 규칙 7번: 2초 이상 로딩이면 스피너 + 진행 메시지
        if (scanState.isProcessing)
          Container(
            color: Colors.black.withOpacity(0.65),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 5),
                  ),
                  SizedBox(height: 28),
                  Text(
                    '영양제를 분석하고 있어요...',
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '잠깐만 기다려 주세요 🙂',
                    style: TextStyle(fontSize: 16, color: Color(0xFFDDDDDD)),
                  ),
                ],
              ),
            ),
          ),

        // 코치마크 — 첫 방문자에게만, 5초 후 자동 소멸
        if (_showCoachMark)
          GestureDetector(
            onTap: _dismissCoachMark,
            child: Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 20),
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.touch_app_rounded,
                              size: 48, color: AppTheme.primaryColor),
                          SizedBox(height: 12),
                          Text(
                            '이 버튼을 눌러\n영양제를 찍어보세요!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF222222),
                                height: 1.5),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '화면을 터치하면 닫혀요',
                            style: TextStyle(
                                fontSize: 15, color: Color(0xFF999999)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 카메라 버튼을 가리키는 화살표
                    const Icon(Icons.arrow_downward_rounded,
                        size: 48, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showPhotoTipsDialog(BuildContext context) {
    if (!kIsWeb) HapticFeedback.lightImpact();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded,
                color: AppTheme.primaryColor, size: 28),
            SizedBox(width: 10),
            Text('잘 찍는 방법',
                style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TipRow(
              icon: Icons.wb_sunny_outlined,
              text: '밝은 곳에서 찍어주세요\n빛이 충분할수록 더 정확해요',
            ),
            SizedBox(height: 16),
            _TipRow(
              icon: Icons.straighten_rounded,
              text: '제품 앞면을 정면으로 찍어주세요\n기울어지면 글자를 읽기 어려워요',
            ),
            SizedBox(height: 16),
            _TipRow(
              icon: Icons.crop_free_rounded,
              text: '제품 전체가 화면에 들어오게 찍어주세요\n박스나 병 전체가 나오면 좋아요',
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (!kIsWeb) HapticFeedback.mediumImpact();
                Navigator.pop(context);
              },
              child: const Text('알겠어요!'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onCameraPressed(BuildContext context, String userId) async {
    if (userId.isEmpty) return;

    // 사용량 한도 초과 시 분석 전에 안내
    final limitReached =
        await ref.read(scanRepositoryProvider).isDailyLimitReached(userId);
    if (!mounted) return;

    if (limitReached) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('오늘은 충분히 사용하셨어요',
              style: TextStyle(fontSize: 20)),
          content: const Text(
            '내일 다시 도와드릴게요 🙂\n(하루 최대 20회 분석)',
            style: TextStyle(fontSize: 17, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인', style: TextStyle(fontSize: 17)),
            ),
          ],
        ),
      );
      return;
    }

    // 카메라 / 앨범 선택 ActionSheet
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded,
                  color: AppTheme.primaryColor, size: 28),
              title: const Text('카메라로 촬영',
                  style: TextStyle(fontSize: 18)),
              onTap: () {
                if (!kIsWeb) HapticFeedback.mediumImpact();
                Navigator.pop(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppTheme.primaryColor, size: 28),
              title: const Text('앨범에서 선택',
                  style: TextStyle(fontSize: 18)),
              onTap: () {
                if (!kIsWeb) HapticFeedback.mediumImpact();
                Navigator.pop(context, ImageSource.gallery);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    final xfile = await _picker.pickImage(source: source);
    if (xfile == null || !mounted) return;

    await ref.read(scanNotifierProvider.notifier).startScan(xfile, userId);
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ),
      ],
    );
  }
}
