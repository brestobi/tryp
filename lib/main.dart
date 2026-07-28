import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp/app/app.dart';
import 'package:tryp/config/environment.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Environment.load();

  await Supabase.initialize(
    url: Environment.supabaseUrl,
    anonKey: Environment.supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: TRYPApp(),
    ),
  );
}
