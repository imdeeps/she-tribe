import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'events_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final name = app.profile?.firstName ?? '';
    final event = app.events.isEmpty ? null : app.events.first;
    final reg = event == null ? null : app.registrationFor(event.id);

    return PageScroll(
      title: name.isEmpty ? 'Welcome' : 'Hi, $name',
      subtitle: 'Dream & build together.',
      onRefresh: app.refresh,
      children: [
        if (app.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(app.error!,
                style: Brand.body(14, color: const Color(0xFFB3123F), weight: FontWeight.w600)),
          ),
        if (event != null) _NextEventCard(event: event, registered: reg?.isPaid ?? false),
        if (event == null)
          SoftCard(
            child: Text(
              'Our next event will be announced soon. Check back here, or pull down to refresh.',
              style: Brand.body(16, height: 1.5),
            ),
          ),
        const SizedBox(height: 20),
        ResponsiveWrap(
          minItemWidth: 280,
          children: [
            _ActionTile(
              icon: Icons.swap_horiz,
              title: 'Ask & Offer wall',
              text: 'Say what you need and what you can offer.',
              onTap: () => app.setTab(2),
            ),
            _ActionTile(
              icon: Icons.flag_outlined,
              title: 'Commitment card',
              text: 'Pick what you will do before the next meet-up.',
              onTap: () => app.setTab(4),
            ),
            if (!app.isMember)
              _ActionTile(
                icon: Icons.workspace_premium_outlined,
                title: 'Become a member',
                text: 'Monthly networking, workshops and the member directory.',
                onTap: () => app.setTab(3),
              ),
          ],
        ),
        const SizedBox(height: 24),
        SoftCard(
          color: Brand.plum,
          borderColor: Brand.plum,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You do not need a business to belong.',
                  style: Brand.display(26, color: Brand.cream, weight: FontWeight.w600, height: 1.2)),
              const SizedBox(height: 14),
              for (final e in stageLabels.values)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('\u2022  $e? Come.',
                      style: Brand.body(17, color: const Color(0xFFF3DFE0))),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NextEventCard extends StatelessWidget {
  const _NextEventCard({required this.event, required this.registered});

  final TribeEvent event;
  final bool registered;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: Brand.blush,
      borderColor: Brand.blush,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tag(registered ? 'You\u2019re registered' : 'Next event',
              bg: Brand.accent, fg: Colors.white),
          const SizedBox(height: 14),
          Text(event.title, style: Brand.display(30, weight: FontWeight.w700, height: 1.1)),
          const SizedBox(height: 10),
          Text(formatDate(event.startsAt), style: Brand.body(16, weight: FontWeight.w600, color: Brand.ink)),
          if (event.venue.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(event.venue, style: Brand.body(16)),
            ),
          if (event.capacity != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Limited to ${event.capacity} women', style: Brand.body(16)),
            ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => EventDetailScreen(eventId: event.id)),
            ),
            child: Text(registered ? 'View your ticket' : 'Reserve your seat'),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: SoftCard(
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: Brand.blush, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: Brand.accent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Brand.display(19, weight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(text, style: Brand.body(14, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
