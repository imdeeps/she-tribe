import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int _view = 0;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return PageScroll(
      title: 'Community',
      subtitle: 'Real networking, not just exchanging handles.',
      onRefresh: app.refresh,
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Ask & Offer'), icon: Icon(Icons.swap_horiz)),
            ButtonSegment(value: 1, label: Text('Member directory'), icon: Icon(Icons.groups_outlined)),
          ],
          selected: {_view},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _view = s.first),
        ),
        const SizedBox(height: 20),
        if (_view == 0) const _Wall() else const _Directory(),
      ],
    );
  }
}

class _Wall extends StatefulWidget {
  const _Wall();

  @override
  State<_Wall> createState() => _WallState();
}

class _WallState extends State<_Wall> {
  final _text = TextEditingController();
  String _kind = 'need';
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    setState(() => _busy = true);
    try {
      await context.read<AppState>().addPost(_kind, t);
      _text.clear();
    } catch (e) {
      if (mounted) snack(context, errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final posts = context.watch<AppState>().posts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add to the wall', style: Brand.display(20)),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'need', label: Text('I need')),
                  ButtonSegment(value: 'offer', label: Text('I can offer')),
                ],
                selected: {_kind},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _text,
                maxLength: 200,
                maxLines: 3,
                minLines: 2,
                decoration: fieldDecoration(
                  _kind == 'need' ? 'What do you need?' : 'What can you offer?',
                  hint: _kind == 'need'
                      ? 'e.g. branding, customers, a photographer, a mentor'
                      : 'e.g. design, legal support, marketing, referrals',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy ? null : _post,
                child: Text(_busy ? 'Posting...' : 'Post'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (posts.isEmpty)
          Text('No posts yet. Be the first to add one.', style: Brand.body(16)),
        for (final p in posts)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PostCard(post: p),
          ),
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final need = post.kind == 'need';
    return SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Tag(need ? 'I NEED' : 'I CAN OFFER',
                  bg: need ? Brand.blush : Brand.plum,
                  fg: need ? const Color(0xFF8F1747) : Brand.cream),
              const SizedBox(width: 10),
              Expanded(
                child: Text(post.authorName,
                    overflow: TextOverflow.ellipsis,
                    style: Brand.body(14, weight: FontWeight.w600, color: Brand.ink)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(post.text, style: Brand.body(16, height: 1.5, color: Brand.ink)),
        ],
      ),
    );
  }
}

class _Directory extends StatelessWidget {
  const _Directory();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!app.isMember) {
      return SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline, color: Brand.accent, size: 32),
            const SizedBox(height: 12),
            Text('The member directory is for members', style: Brand.display(22)),
            const SizedBox(height: 8),
            Text(
              'Members can find women to collaborate with, learn from and refer. Only women who choose to be listed appear here.',
              style: Brand.body(16, height: 1.5),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => app.setTab(3),
              child: const Text('See membership'),
            ),
          ],
        ),
      );
    }
    if (app.directory.isEmpty) {
      return Text(
        'No one has opted in to the directory yet. Check back soon.',
        style: Brand.body(16),
      );
    }
    return ResponsiveWrap(
      minItemWidth: 300,
      children: [for (final m in app.directory) _MemberCard(member: m)],
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member});

  final Profile member;

  @override
  Widget build(BuildContext context) {
    final handle = member.instagram.trim().replaceAll('@', '').replaceAll(' ', '');
    return SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(member.fullName, style: Brand.display(21, weight: FontWeight.w700)),
          if (member.businessName.isNotEmpty)
            Text(member.businessName, style: Brand.body(15, weight: FontWeight.w600, color: Brand.ink)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Tag(stageLabels[member.stage] ?? member.stage),
              Tag(member.roleTag, bg: Brand.plum, fg: Brand.cream),
            ],
          ),
          if (member.about.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(member.about, style: Brand.body(15, height: 1.45)),
          ],
          if (member.lookingFor.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Looking for: ${member.lookingFor.join(', ')}',
                style: Brand.body(14, weight: FontWeight.w600, color: Brand.ink)),
          ],
          if (handle.isNotEmpty)
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
              onPressed: () => openUrl('https://instagram.com/$handle'),
              child: Text('@$handle',
                  style: Brand.body(14, color: Brand.accent, weight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}
