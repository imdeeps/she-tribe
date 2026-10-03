import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'pay_screen.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return PageScroll(
      title: 'Events',
      subtitle: 'Small, beautifully hosted and highly interactive.',
      onRefresh: app.refresh,
      children: [
        if (app.events.isEmpty)
          SoftCard(
            child: Text('No events are open right now. Our next one will appear here.',
                style: Brand.body(16, height: 1.5)),
          ),
        for (final e in app.events)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _EventCard(event: e, reg: app.registrationFor(e.id)),
          ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.reg});

  final TribeEvent event;
  final Registration? reg;

  @override
  Widget build(BuildContext context) {
    final lowest = event.tiers.isEmpty ? null : event.tiers.first.priceInr;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => EventDetailScreen(eventId: event.id)),
      ),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reg?.isPaid ?? false) const Tag('You\u2019re registered'),
            if (reg != null && !reg!.isPaid) const Tag('Payment pending'),
            if (reg != null) const SizedBox(height: 10),
            Text(event.title, style: Brand.display(26, weight: FontWeight.w700, height: 1.15)),
            const SizedBox(height: 8),
            Text(formatDate(event.startsAt),
                style: Brand.body(15, weight: FontWeight.w600, color: Brand.ink)),
            if (event.venue.isNotEmpty) Text(event.venue, style: Brand.body(15)),
            const SizedBox(height: 10),
            Text(
              lowest == null ? 'Tickets coming soon' : 'Tickets from ${formatInr(lowest)}',
              style: Brand.body(15, weight: FontWeight.w700, color: Brand.accent),
            ),
          ],
        ),
      ),
    );
  }
}

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _busy = false;

  void _openPay(String paymentId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PayScreen(paymentId: paymentId)),
    );
  }

  Future<void> _reserve(AppState app, TicketTier tier) async {
    setState(() => _busy = true);
    try {
      final pay = await app.requestTicketPayment(widget.eventId, tier.id);
      if (!mounted) return;
      if (pay.status == 'approved') {
        snack(context, 'You\u2019re registered!');
      } else {
        _openPay(pay.id);
      }
    } catch (e) {
      if (mounted) snack(context, errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    TribeEvent? event;
    for (final e in app.events) {
      if (e.id == widget.eventId) event = e;
    }
    final reg = app.registrationFor(widget.eventId);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Brand.cream,
        foregroundColor: Brand.ink,
        title: const Text('Event'),
      ),
      body: event == null
          ? const Center(child: Text('This event is no longer available.'))
          : RefreshIndicator(
              onRefresh: app.refresh,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    children: _content(app, event, reg),
                  ),
                ),
              ),
            ),
    );
  }

  List<Widget> _content(AppState app, TribeEvent event, Registration? reg) {
    return [
      Text(event.title, style: Brand.display(34, weight: FontWeight.w700, height: 1.1)),
      if (event.subtitle.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(event.subtitle, style: Brand.body(17, height: 1.5)),
        ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Tag(formatDate(event.startsAt)),
          if (event.venue.isNotEmpty) Tag(event.venue),
          if (event.capacity != null) Tag('${event.capacity} seats'),
        ],
      ),
      if (reg?.isPaid ?? false) ...[
        const SizedBox(height: 20),
        SoftCard(
          color: Brand.plum,
          borderColor: Brand.plum,
          child: Row(
            children: [
              const Icon(Icons.confirmation_number, color: Brand.coral, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('You\u2019re in!',
                        style: Brand.display(22, color: Brand.cream, weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${app.profile?.fullName ?? ''} \u00B7 ${formatInr(reg!.amountInr)} paid',
                        style: Brand.body(15, color: const Color(0xFFF3DFE0))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      if (event.description.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text(event.description, style: Brand.body(17, height: 1.6)),
      ],
      if (event.highlights.isNotEmpty) ...[
        const SizedBox(height: 24),
        Text('What happens', style: Brand.display(24)),
        for (final h in event.highlights) PerkRow(h),
      ],
      const SizedBox(height: 28),
      Text('Tickets', style: Brand.display(24)),
      if (reg != null && app.lastPaymentRejected(reg.id) && app.openPaymentForRegistration(reg.id) == null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Your last payment could not be confirmed. You can try again, or message us with your transaction ID.',
            style: Brand.body(14, color: const Color(0xFFB3123F), weight: FontWeight.w600, height: 1.4),
          ),
        ),
      const SizedBox(height: 12),
      if (event.tiers.isEmpty)
        Text('Tickets coming soon.', style: Brand.body(16))
      else
        ResponsiveWrap(
          minItemWidth: 250,
          children: [
            for (final t in event.tiers) _tierCard(app, event, t, reg),
          ],
        ),
    ];
  }

  Widget _tierCard(AppState app, TribeEvent event, TicketTier t, Registration? reg) {
    final memberPrice = (app.isMember && t.memberPriceInr != null) ? t.memberPriceInr! : null;
    final price = memberPrice ?? t.priceInr;
    final mine = reg != null && reg.tierId == t.id;
    final paid = reg?.isPaid ?? false;

    final open = (mine && reg != null) ? app.openPaymentForRegistration(reg.id) : null;
    Widget action;
    if (paid) {
      action = FilledButton(
        onPressed: null,
        child: Text(mine ? 'Your ticket' : 'Already registered'),
      );
    } else if (open != null) {
      action = FilledButton(
        onPressed: () => _openPay(open.id),
        child: Text(open.status == 'submitted' ? 'Awaiting confirmation' : 'Complete payment'),
      );
    } else {
      action = FilledButton(
        onPressed: _busy ? null : () => _reserve(app, t),
        child: Text(_busy
            ? 'Please wait...'
            : (price == 0 ? 'Reserve (free)' : 'Reserve ${formatInr(price)}')),
      );
    }

    return SoftCard(
      borderColor: mine ? Brand.accent : Brand.cardLine,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.name, style: Brand.display(22, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatInr(price), style: Brand.display(30, weight: FontWeight.w700, color: Brand.accent)),
              if (memberPrice != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Text('member price', style: Brand.body(13, weight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (final p in t.perks) PerkRow(p),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: action),
        ],
      ),
    );
  }
}
