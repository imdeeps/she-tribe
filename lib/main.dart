import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import 'backend.dart';
import 'config.dart';
import 'screens/auth_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/public_ticket_screen.dart';
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

/// A private ticket link looks like https://app.shetribe.in/?t=TOKEN
String? get _ticketToken {
  if (!kIsWeb || Config.isDemo) return null;
  final t = Uri.base.queryParameters['t'];
  return (t == null || t.length < 20) ? null : t;
}

class SheTribeApp extends StatelessWidget {
  const SheTribeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'She Tribe',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: _ticketToken == null ? const Root() : PublicTicketScreen(token: _ticketToken!),
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
