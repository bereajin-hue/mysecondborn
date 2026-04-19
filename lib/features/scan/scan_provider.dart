import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/scan_repository.dart';

export 'data/scan_repository.dart' show ScanRepository;

final scanRepositoryProvider = Provider<ScanRepository>((ref) => ScanRepository());

// 스캔 플로우 상태 — HomeScreen 로딩 오버레이와 에러 표시에 사용
class ScanState {
  final bool isProcessing;
  final String? scanId;
  final String? error;

  const ScanState({this.isProcessing = false, this.scanId, this.error});
}

class ScanNotifier extends StateNotifier<ScanState> {
  ScanNotifier(this._repo) : super(const ScanState());

  final ScanRepository _repo;

  Future<void> startScan(XFile xfile, String userId) async {
    state = const ScanState(isProcessing: true);
    try {
      final scanId = await _repo.captureAndAnalyze(xfile, userId);
      state = ScanState(scanId: scanId);
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = ScanState(error: msg.isNotEmpty ? msg : '잠깐 문제가 생겼어요. 다시 시도해주세요.');
    }
  }

  void reset() => state = const ScanState();
}

final scanNotifierProvider = StateNotifierProvider<ScanNotifier, ScanState>(
  (ref) => ScanNotifier(ref.read(scanRepositoryProvider)),
);

// ResultScreen 전용 — scans 테이블을 실시간 구독하여 gemini_response 업데이트 감지
final scanStreamProvider = StreamProvider.autoDispose.family<Map<String, dynamic>?, String>(
  (ref, scanId) {
    return Supabase.instance.client
        .from('scans')
        .stream(primaryKey: ['id'])
        .eq('id', scanId)
        .map((rows) {
          if (rows.isEmpty) return null;
          return rows.first;
        });
  },
);
