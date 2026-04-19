import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO: Supabase.initialize(), Sentry.init() 여기서 순서대로 초기화
  runApp(const ProviderScope(child: MomPillApp()));
}
