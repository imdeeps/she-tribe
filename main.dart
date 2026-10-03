import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import 'backend.dart';
import 'config.dart';
import 'screens/auth_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Config.isDemo) {
    await Supabase.initialize(
      url: Config.supabaseUrl,
      anonKey: Config.supabaseAnonKey,
    );
  }
  final Backend backend = Config.isDemo ? DemoBackend() : SupabaseBackend();
  runApp(
    ChangeNotifierProvider<AppState>(
      create: (_) => AppState(backend)..init(),
      child: const SheTribeApp(),
    ),
  );
}

class SheTribeApp extends StatelessWidget {
  const SheTribeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'She Tribe',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const Root(),
    );
  }
}

class Root extends StatelessWidget {
  const Root({super.key});

  @override
  Widget build(BuildContext context) {
    final stage = context.watch<AppState>().stage;
    switch (stage) {
      case AppStage.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: Brand.accent)),
        );
      case AppStage.signedOut:
        return const AuthScreen();
      case AppStage.needsProfile:
        return const ProfileSetupScreen();
      case AppStage.ready:
        return const Shell();
    }
  }
}
