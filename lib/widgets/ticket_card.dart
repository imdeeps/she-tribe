import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models.dart';
import '../theme.dart';

/// The ticket itself: event details, a QR code and the ticket number.
class TicketCard extends StatelessWidget {
  const TicketCard({
    super.key,
    required this.eventTitle,
    required this.startsAt,
    required this.venue,
    required this.tierName,
    required this.attendeeName,
    required this.code,
  });

  final String eventTitle;
  final DateTime? startsAt;
  final String venue;
  final String tierName;
  final String attendeeName;
  final String code;

  @override
  Widget build(BuildContext context) {
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
                Text(eventTitle,
                    style: Brand.display(26, weight: FontWeight.w700, color: Brand.cream, height: 1.15)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                field('Date and time', formatDate(startsAt)),
                if (venue.isNotEmpty) field('Venue', venue),
                if (attendeeName.isNotEmpty) field('Name', attendeeName),
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
                    data: 'SHETRIBE:$code',
                    version: QrVersions.auto,
                    size: 190,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Text(code,
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
