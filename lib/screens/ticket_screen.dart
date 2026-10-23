import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// The member's ticket for an event: details, ticket number and a QR code
/// that can be scanned at the door.
class TicketScreen extends StatelessWidget {
  const TicketScreen({super.key, required this.eventId});

  final String eventId;

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
                  children: [_ticket(app, event, reg)],
                ),
              ),
            ),
    );
  }

  Widget _ticket(AppState app, TribeEvent event, Registration reg) {
    String tierName = '';
    for (final t in event.tiers) {
      if (t.id == reg.tierId) tierName = t.name;
    }
    final name = app.profile?.fullName ?? '';

    Widget field(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: Brand.body(12, weight: FontWeight.w700, color: Brand.inkSoft)),
              const SizedBox(height: 2),
              Text(value, style: Brand.body(17, weight: FontWeight.w600, color: Brand.ink)),
            ],
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: Brand.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Brand.cardLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Brand.plum,
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SHE TRIBE',
                    style: Brand.body(13, weight: FontWeight.w700, color: Brand.coral)
                        .copyWith(letterSpacing: 3)),
                const SizedBox(height: 6),
                Text(event.title,
                    style: Brand.display(26, weight: FontWeight.w700, color: Brand.cream, height: 1.15)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                field('Date and time', formatDate(event.startsAt)),
                if (event.venue.isNotEmpty) field('Venue', event.venue),
                if (name.isNotEmpty) field('Name', name),
                if (tierName.isNotEmpty) field('Ticket', tierName),
              ],
            ),
          ),
          const Divider(height: 1, color: Brand.cardLine),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: 'SHETRIBE:${reg.id}',
                    version: QrVersions.auto,
                    size: 190,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Text(reg.code,
                    style: Brand.display(28, weight: FontWeight.w700, color: Brand.accent)
                        .copyWith(letterSpacing: 2)),
                const SizedBox(height: 4),
                Text('Show this at the entrance',
                    style: Brand.body(14, weight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
