import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../config.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'profile_setup_screen.dart';

class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, AppState app) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your profile, posts, registrations and membership. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep my account')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await app.deleteAccount();
    } catch (e) {
      if (context.mounted) snack(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.profile;
    if (p == null) return const SizedBox.shrink();

    return PageScroll(
      title: 'Me',
      onRefresh: app.refresh,
      children: [
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.fullName, style: Brand.display(26, weight: FontWeight.w700)),
              if (p.businessName.isNotEmpty)
                Text(p.businessName, style: Brand.body(16, weight: FontWeight.w600, color: Brand.ink)),
              if (app.phone != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('WhatsApp ${app.phone}', style: Brand.body(14)),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Tag(stageLabels[p.stage] ?? p.stage),
                  Tag(p.roleTag, bg: Brand.plum, fg: Brand.cream),
                  if (app.isMember) const Tag('Member', bg: Brand.accent, fg: Colors.white),
                ],
              ),
              if (p.about.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(p.about, style: Brand.body(15, height: 1.5)),
              ],
              if (p.lookingFor.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Looking for: ${p.lookingFor.join(', ')}',
                    style: Brand.body(14, weight: FontWeight.w600, color: Brand.ink)),
              ],
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ProfileSetupScreen(editing: true)),
                ),
                child: const Text('Edit profile'),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: p.directoryOptIn,
                onChanged: (v) async {
                  try {
                    await app.setDirectoryOptIn(v);
                  } catch (e) {
                    if (context.mounted) snack(context, errorText(e));
                  }
                },
                title: Text('Show me in the member directory',
                    style: Brand.body(15, weight: FontWeight.w600, color: Brand.ink)),
                subtitle: Text('Only paying members can see it.', style: Brand.body(13)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _CommitmentCard(),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: () => openUrl(Config.privacyUrl),
              child: const Text('Privacy Policy'),
            ),
            TextButton(onPressed: app.signOut, child: const Text('Sign out')),
            TextButton(
              onPressed: () => _confirmDelete(context, app),
              child: Text('Delete account',
                  style: Brand.body(14, color: const Color(0xFFB3123F), weight: FontWeight.w600)),
            ),
          ],
        ),
      ],
    );
  }
}

class _CommitmentCard extends StatefulWidget {
  const _CommitmentCard();

  @override
  State<_CommitmentCard> createState() => _CommitmentCardState();
}

class _CommitmentCardState extends State<_CommitmentCard> {
  late Set<String> _picks;
  late TextEditingController _goal;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final c = context.read<AppState>().commitment;
    _picks = {...c.picks};
    _goal = TextEditingController(text: c.goal);
  }

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await context
          .read<AppState>()
          .saveCommitment(Commitment(picks: _picks.toList(), goal: _goal.text));
      if (mounted) snack(context, 'Saved. We\u2019re cheering you on!');
    } catch (e) {
      if (mounted) snack(context, errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: Brand.blush,
      borderColor: Brand.blush,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My commitment card', style: Brand.display(22, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Before the next She Tribe meet-up, I will:', style: Brand.body(15)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in commitmentOptions)
                FilterChip(
                  label: Text(o),
                  selected: _picks.contains(o),
                  backgroundColor: Colors.white,
                  selectedColor: Colors.white,
                  checkmarkColor: Brand.accent,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _picks.add(o);
                    } else {
                      _picks.remove(o);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _goal,
            maxLength: 140,
            decoration: fieldDecoration('My own goal', hint: 'Write it in your own words'),
          ),
          const SizedBox(height: 4),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving...' : 'Save my commitment'),
          ),
        ],
      ),
    );
  }
}
