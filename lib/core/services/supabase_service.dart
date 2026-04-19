import 'package:supabase_flutter/supabase_flutter.dart';

// 앱 전역에서 Supabase 클라이언트 단일 진입점
class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
}
