import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/ticket_card.dart';

/// Opens straight to a ticket from its private link (no sign-in needed).
class PublicTicketScreen extends StatefulWidget {
  const PublicTicketScreen({super.key, required this.token});

  final String token;

  @override
  State<PublicTicketScreen> createState() => _PublicTicketScreenState();
}

class _PublicTicketScreenState extends State<PublicTicketScreen> {
  late final Future<Map<String, dynamic>?> _future = _load();

  Future<Map<String, dynamic>?> _load() async {
    final rows = await Supabase.instance.client
        .rpc('get_public_ticket', params: {'p_token': widget.token});
    if (rows is List && rows.isNotEmpty) {
      return Map<String, dynamic>.from(rows.first as Map);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Brand.cream,
        foregroundColor: Brand.ink,
        title: const Text('Your ticket'),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: Brand.accent));
          }
          final t = snap.data;
          if (snap.hasError || t == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('We couldn’t find this ticket.',
                        style: Brand.display(24, weight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('The link may be incomplete. Open the app and sign in to see your ticket.',
                        textAlign: TextAlign.center, style: Brand.body(15, height: 1.5)),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => openUrl(Config.appUrl),
                      child: const Text('Open She Tribe'),
                    ),
                  ],
                ),
              ),
            );
          }
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  TicketCard(
                    eventTitle: (t['event_title'] ?? '').toString(),
                    startsAt: t['starts_at'] == null
                        ? null
                        : DateTime.tryParse(t['starts_at'].toString())?.toLocal(),
                    venue: (t['venue'] ?? '').toString(),
                    tierName: (t['tier_name'] ?? '').toString(),
                    attendeeName: (t['attendee_name'] ?? '').toString(),
                    code: (t['ticket_code'] ?? '').toString(),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => openUrl(Config.appUrl),
                    child: const Text('Open She Tribe'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
