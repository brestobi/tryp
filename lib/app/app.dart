import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';

class TRYPApp extends ConsumerWidget {
  const TRYPApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'TRYP',
      theme: TRYPTheme.lightTheme,
      darkTheme: TRYPTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: buildRouter(),
      debugShowCheckedModeBanner: false,
    );
  }
}
