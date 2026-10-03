import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../config.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'pay_screen.dart';

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  bool _busy = false;

  void _openPay(String paymentId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PayScreen(paymentId: paymentId)),
    );
  }

  Future<void> _subscribe(Plan plan) async {
    setState(() => _busy = true);
    try {
      final pay = await context.read<AppState>().requestMembershipPayment(plan.code);
      if (!mounted) return;
      _openPay(pay.id);
    } catch (e) {
      if (mounted) snack(context, errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final m = app.membership;
    Plan? current;
    if (app.isMember) {
      for (final p in app.plans) {
        if (p.code == m?.planCode) current = p;
      }
    }

    return PageScroll(
      title: 'Membership',
      subtitle: 'Join free, or go deeper with a membership.',
      onRefresh: app.refresh,
      children: [
        if (app.isMember)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SoftCard(
              color: Brand.plum,
              borderColor: Brand.plum,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(current?.name ?? 'Member',
                      style: Brand.display(24, color: Brand.cream, weight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    m?.status == 'cancelled'
                        ? 'Ends on ${m!.currentEnd == null ? 'the end of your period' : formatShortDate(m.currentEnd!)}'
                        : (m?.currentEnd == null
                            ? 'Active'
                            : 'Active until ${formatShortDate(m!.currentEnd!)}'),
                    style: Brand.body(15, color: const Color(0xFFF3DFE0)),
                  ),
                ],
              ),
            ),
          ),
        ResponsiveWrap(
          minItemWidth: 290,
          children: [
            _freeCard(app),
            for (final p in app.plans) _planCard(app, p),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Memberships last for the period shown and don\u2019t renew automatically. Renew any time from here and the time is added on top. To change or cancel, contact the She Tribe team.',
          style: Brand.body(14, height: 1.5),
        ),
      ],
    );
  }

  Widget _freeCard(AppState app) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('She Tribe Free', style: Brand.display(24, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Free', style: Brand.display(30, weight: FontWeight.w700, color: Brand.accent)),
          const SizedBox(height: 6),
          const PerkRow('The She Tribe community'),
          const PerkRow('Occasional networking'),
          const PerkRow('Event announcements'),
          const PerkRow('Ask & Offer wall'),
          const SizedBox(height: 18),
          const SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: null, child: Text('You\u2019re in')),
          ),
        ],
      ),
    );
  }

  Widget _planCard(AppState app, Plan plan) {
    final isCurrent = app.isMember && app.membership?.planCode == plan.code;
    final open = app.openMembershipPayment(plan.code);
    final short = plan.name.replaceFirst('She Tribe ', '');
    Widget action;
    if (open != null) {
      action = FilledButton(
        onPressed: () => _openPay(open.id),
        child: Text(open.status == 'submitted' ? 'Awaiting confirmation' : 'Complete payment'),
      );
    } else if (Config.membershipPurchaseAllowed) {
      action = FilledButton(
        onPressed: _busy ? null : () => _subscribe(plan),
        child: Text(_busy
            ? 'Please wait...'
            : (isCurrent ? 'Renew $short' : 'Join $short')),
      );
    } else if (isCurrent) {
      action = const FilledButton(onPressed: null, child: Text('Your plan'));
    } else {
      action = Text('Memberships are managed outside the app.',
          style: Brand.body(14, height: 1.4));
    }

    return SoftCard(
      borderColor: isCurrent ? Brand.accent : Brand.cardLine,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(plan.name, style: Brand.display(24, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          if (plan.tagline.isNotEmpty) Text(plan.tagline, style: Brand.body(14, height: 1.4)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatInr(plan.priceInr),
                  style: Brand.display(30, weight: FontWeight.w700, color: Brand.accent)),
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 5),
                child: Text('/ ${plan.interval}', style: Brand.body(14, weight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final p in plan.perks) PerkRow(p),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: action),
        ],
      ),
    );
  }
}
