import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../config.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, this.editing = false});

  final bool editing;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final TextEditingController _name;
  late final TextEditingController _business;
  late final TextEditingController _about;
  late final TextEditingController _insta;
  late String _stage;
  late String _role;
  late Set<String> _looking;
  late bool _optIn;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppState>().profile;
    _name = TextEditingController(text: p?.fullName ?? '');
    _business = TextEditingController(text: p?.businessName ?? '');
    _about = TextEditingController(text: p?.about ?? '');
    _insta = TextEditingController(text: p?.instagram ?? '');
    _stage = p?.stage ?? 'idea';
    _role = p?.roleTag ?? 'Aspiring Entrepreneur';
    _looking = {...?p?.lookingFor};
    _optIn = p?.directoryOptIn ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _business.dispose();
    _about.dispose();
    _insta.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Please tell us your name.');
      return;
    }
    final app = context.read<AppState>();
    final id = app.profile?.id ?? app.backend.userId;
    if (id == null) {
      setState(() => _error = 'Please sign in again.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await app.saveProfile(Profile(
        id: id,
        fullName: _name.text,
        businessName: _business.text,
        stage: _stage,
        roleTag: _role,
        lookingFor: _looking.toList(),
        about: _about.text,
        instagram: _insta.text,
        directoryOptIn: _optIn,
      ));
      if (mounted && widget.editing) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 10),
        child: Text(text, style: Brand.body(16, weight: FontWeight.w700, color: Brand.ink)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.editing
          ? AppBar(
              backgroundColor: Brand.cream,
              foregroundColor: Brand.ink,
              title: const Text('Edit profile'),
            )
          : null,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              children: [
                if (!widget.editing) ...[
                  Text('Tell us about you',
                      style: Brand.display(34, weight: FontWeight.w700, height: 1.1)),
                  const SizedBox(height: 8),
                  Text(
                    'This helps the tribe connect you with the right women. You can change it any time.',
                    style: Brand.body(16, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                ],
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  decoration: fieldDecoration('Full name'),
                ),
                _label('Where are you on your journey?'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in stageLabels.entries)
                      ChoiceChip(
                        label: Text(e.value),
                        selected: _stage == e.key,
                        selectedColor: Brand.blush,
                        onSelected: (_) => setState(() => _stage = e.key),
                      ),
                  ],
                ),
                _label('I am'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in roleOptions)
                      ChoiceChip(
                        label: Text(r),
                        selected: _role == r,
                        selectedColor: Brand.blush,
                        onSelected: (_) => setState(() => _role = r),
                      ),
                  ],
                ),
                _label('I\u2019m looking for'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final o in lookingForOptions)
                      FilterChip(
                        label: Text(o),
                        selected: _looking.contains(o),
                        selectedColor: Brand.blush,
                        onSelected: (v) => setState(() {
                          if (v) {
                            _looking.add(o);
                          } else {
                            _looking.remove(o);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _business,
                  textCapitalization: TextCapitalization.words,
                  decoration: fieldDecoration('Business or idea (optional)'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _about,
                  maxLines: 3,
                  maxLength: 240,
                  decoration: fieldDecoration(
                    'Your 60-second intro (optional)',
                    hint: 'I do ... I\u2019m working on ... I\u2019m looking for ...',
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _insta,
                  autocorrect: false,
                  decoration: fieldDecoration('Instagram handle (optional)', hint: '@yourhandle'),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _optIn,
                  onChanged: (v) => setState(() => _optIn = v),
                  title: Text('Show me in the member directory',
                      style: Brand.body(16, weight: FontWeight.w600, color: Brand.ink)),
                  subtitle: Text(
                    'Only paying members can see the directory, and only women who switch this on appear in it. You can change this any time.',
                    style: Brand.body(14, height: 1.4),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: Brand.body(14, color: const Color(0xFFB3123F), weight: FontWeight.w600)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Saving...' : (widget.editing ? 'Save changes' : 'Join the tribe')),
                ),
                if (!widget.editing)
                  TextButton(
                    onPressed: () => openUrl(Config.privacyUrl),
                    child: Text('By continuing you agree to our Privacy Policy',
                        textAlign: TextAlign.center,
                        style: Brand.body(13, color: Brand.accent, weight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
