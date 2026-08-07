import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tryp_driver/app/app_variant.dart';
import 'package:tryp_driver/app/router.dart';
import 'package:tryp_driver/app/theme.dart';

class TRYPApp extends ConsumerWidget {
  final AppVariant variant;

  const TRYPApp({
    super.key,
    required this.variant,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: variant.displayName,
      theme: TRYPTheme.lightTheme,
      darkTheme: TRYPTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: buildRouter(variant),
      debugShowCheckedModeBanner: false,
    );
  }
}
