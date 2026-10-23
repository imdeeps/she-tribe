import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../config.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/ticket_card.dart';
import '../widgets/whatsapp_ask.dart';

/// The member's ticket for an event, with ways to keep a copy on their phone.
class TicketScreen extends StatelessWidget {
  const TicketScreen({super.key, required this.eventId});

  final String eventId;

  String _message(TribeEvent event, Registration reg) {
    final link = '${Config.appUrl}/?t=${reg.ticketToken}';
    return 'My She Tribe ticket\n${event.title}\n${formatDate(event.startsAt)}\n'
        '${event.venue.isEmpty ? '' : '${event.venue}\n'}'
        'Ticket ${reg.code}\n$link';
  }

  Future<void> _whatsapp(BuildContext context, AppState app, TribeEvent event, Registration reg) async {
    final text = Uri.encodeComponent(_message(event, reg));
    final saved = (app.whatsapp ?? '').replaceAll(RegExp(r'\D'), '');
    final url = saved.isNotEmpty ? 'https://wa.me/$saved?text=$text' : 'https://wa.me/?text=$text';
    try {
      await openUrl(url);
    } catch (_) {
      if (context.mounted) snack(context, 'Could not open WhatsApp. Use Copy ticket link instead.');
    }
  }

  Future<void> _copy(BuildContext context, Registration reg) async {
    await Clipboard.setData(ClipboardData(text: '${Config.appUrl}/?t=${reg.ticketToken}'));
    if (context.mounted) snack(context, 'Ticket link copied');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    TribeEvent? event;
    for (final e in app.events) {
      if (e.id == eventId) event = e;
    }
    final reg = app.registrationFor(eventId);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Brand.cream,
        foregroundColor: Brand.ink,
        title: const Text('Your ticket'),
      ),
      body: (event == null || reg == null || !reg.isPaid)
          ? const Center(child: Text('Your ticket will appear here once your payment is confirmed.'))
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  children: [
                    TicketCard(
                      eventTitle: event.title,
                      startsAt: event.startsAt,
                      venue: event.venue,
                      tierName: event.tiers
                          .where((t) => t.id == reg.tierId)
                          .map((t) => t.name)
                          .firstOrNull ??
                          '',
                      attendeeName: app.profile?.fullName ?? '',
                      code: reg.code,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _whatsapp(context, app, event!, reg),
                      icon: const Icon(Icons.send),
                      label: Text((app.whatsapp ?? '').isNotEmpty
                          ? 'Send to my WhatsApp'
                          : 'Share on WhatsApp'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _copy(context, reg),
                      icon: const Icon(Icons.link),
                      label: const Text('Copy ticket link'),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Anyone with your ticket link can see this ticket, so share it only with people you trust.',
                      textAlign: TextAlign.center,
                      style: Brand.body(13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    const WhatsappAsk(
                      title: 'Save your WhatsApp number',
                      body: 'Then “Send to my WhatsApp” opens your own chat, so your ticket is always one tap away.',
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
