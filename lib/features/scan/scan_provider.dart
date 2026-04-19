import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/scan_repository.dart';

final scanRepositoryProvider = Provider<ScanRepository>((ref) => ScanRepository());

// scan 화면 전체 상태 — isProcessing 동안 HomeScreen에 오버레이 표시
class ScanState {
  final bool isProcessing;
  final String? scanId;
  final String? error;

  const ScanState({this.isProcessing = false, this.scanId, this.error});

  ScanState copyWith({bool? isProcessing, String? scanId, String? error}) => ScanState(
        isProcessing: isProcessing ?? this.isProcessing,
        scanId: scanId ?? this.scanId,
        error: error ?? this.error,
      );
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

// ResultScreen이 scanId로 Supabase에서 결과를 조회
final scanResultProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, scanId) async {
  final res = await Supabase.instance.client
      .from('scans')
      .select('gemini_response')
      .eq('id', scanId)
      .single();
  return res['gemini_response'] as Map<String, dynamic>?;
});
