import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../config.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _addr => _email.text.trim().toLowerCase();
  bool get _validEmail => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_addr);

  Future<void> _sendCode() async {
    if (!_validEmail) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    await _run(() async {
      await context.read<AppState>().sendCode(_addr);
      if (mounted) setState(() => _codeSent = true);
    });
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Enter the code from your email.');
      return;
    }
    await _run(() => context.read<AppState>().verifyCode(_addr, code));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset('assets/logo.png', height: 170),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome to the tribe',
                    textAlign: TextAlign.center,
                    style: Brand.display(32, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'For women who dream, build and grow. You do not need a business to belong.',
                    textAlign: TextAlign.center,
                    style: Brand.body(16, height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _email,
                    enabled: !_codeSent && !_busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: fieldDecoration(
                      'Email address',
                      hint: 'you@example.com',
                      helper: _codeSent
                          ? null
                          : 'We\u2019ll email you a sign-in code.',
                    ),
                    onSubmitted: (_) => _codeSent ? null : _sendCode(),
                  ),
                  if (_codeSent) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: fieldDecoration(
                        'Code from your email',
                        helper: Config.isDemo
                            ? 'Demo mode: use the dummy code ${Config.demoCode}'
                            : 'Check your inbox (and spam) for $_addr',
                      ),
                      onSubmitted: (_) => _verify(),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: Brand.body(14, color: const Color(0xFFB3123F), weight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _busy ? null : (_codeSent ? _verify : _sendCode),
                    child: Text(_busy
                        ? 'Please wait...'
                        : (_codeSent ? 'Verify and continue' : 'Send me a code')),
                  ),
                  if (_codeSent)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: _busy ? null : _sendCode,
                          child: const Text('Send code again'),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _codeSent = false;
                                    _code.clear();
                                    _error = null;
                                  }),
                          child: const Text('Change email'),
                        ),
                      ],
                    ),
                  if (Config.isDemo) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() => context.read<AppState>().signInDemo()),
                      child: const Text('Explore in demo mode'),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => openUrl(Config.privacyUrl),
                    child: Text('Privacy Policy',
                        style: Brand.body(14, color: Brand.accent, weight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
