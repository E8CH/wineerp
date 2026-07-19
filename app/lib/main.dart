import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/env.dart';
import 'core/router.dart';
import 'core/theme.dart';

void main() {
  // 릴리스인데 API 주소가 에뮬레이터 기본값이면 즉시 멈춘다 —
  // 시연 자리에서 "왜 아무것도 안 되지"로 발견하는 것보다 낫다.
  Env.assertConfigured();
  runApp(const ProviderScope(child: WineerpApp()));
}

class WineerpApp extends ConsumerWidget {
  const WineerpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'wineerp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
