import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/routing/app_router.dart';
import 'core/storage/app_config.dart';
import 'core/theme/app_theme.dart';

/// Top-level widget for Ludo Royale.
class LudoRoyaleApp extends ConsumerStatefulWidget {
  const LudoRoyaleApp({super.key});

  @override
  ConsumerState<LudoRoyaleApp> createState() => _LudoRoyaleAppState();
}

class _LudoRoyaleAppState extends ConsumerState<LudoRoyaleApp> {
  late final _router = buildAppRouter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppConfig.init().then((_) {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Ludo Royale',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routerConfig: _router,
    );
  }
}
