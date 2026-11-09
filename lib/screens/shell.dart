import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../config.dart';
import '../theme.dart';
import 'admin_screen.dart';
import 'community_screen.dart';
import 'events_screen.dart';
import 'home_screen.dart';
import 'me_screen.dart';
import 'membership_screen.dart';
import 'pay_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A link like https://app.shetribe.in/?pay=1 (from a reminder email) opens the
    // member's unfinished payment, so she can scan the QR or open her UPI app straight away.
    if (kIsWeb && !Config.isDemo && Uri.base.queryParameters['pay'] != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final open = context.read<AppState>().payments.where((p) => p.status == 'awaiting').toList();
        if (open.isEmpty) return;
        open.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => PayScreen(paymentId: open.first.id)),
        );
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Refresh when the user comes back from the payment page.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AppState>().refresh();
    }
  }

  static const _baseItems = <(IconData, IconData, String)>[
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.event_outlined, Icons.event, 'Events'),
    (Icons.groups_outlined, Icons.groups, 'Community'),
    (Icons.workspace_premium_outlined, Icons.workspace_premium, 'Membership'),
    (Icons.person_outline, Icons.person, 'Me'),
  ];
  static const _adminItem =
      (Icons.verified_outlined, Icons.verified, 'Payments');

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final items = [..._baseItems, if (app.isAdmin) _adminItem];
    final index = app.tab >= items.length ? 0 : app.tab;
    final pages = <Widget>[
      const HomeScreen(),
      const EventsScreen(),
      const CommunityScreen(),
      const MembershipScreen(),
      const MeScreen(),
      if (app.isAdmin) const AdminScreen(),
    ];

    final body = Column(
      children: [
        if (Config.isDemo)
          Container(
            width: double.infinity,
            color: Brand.plum,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            child: SafeArea(
              bottom: false,
              child: Text(
                'Demo mode: sample data, payments are simulated',
                textAlign: TextAlign.center,
                style: Brand.body(13, color: Brand.cream, weight: FontWeight.w600),
              ),
            ),
          ),
        Expanded(child: IndexedStack(index: index, children: pages)),
      ],
    );

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 720;
      final extended = c.maxWidth >= 1100;

      if (!wide) {
        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: app.setTab,
            // With the extra admin tab there are six items, which are too many
            // to label on a phone, so only the selected one shows its label.
            labelBehavior: items.length > 5
                ? NavigationDestinationLabelBehavior.onlyShowSelected
                : NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              for (final it in items)
                NavigationDestination(
                  icon: it.$3 == 'Payments' && app.pending.isNotEmpty
                      ? Badge(label: Text('${app.pending.length}'), child: Icon(it.$1))
                      : Icon(it.$1),
                  selectedIcon: Icon(it.$2, color: Brand.accent),
                  label: it.$3 == 'Membership' ? 'Plans' : it.$3,
                ),
            ],
          ),
        );
      }

      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                backgroundColor: Brand.card,
                extended: extended,
                selectedIndex: index,
                onDestinationSelected: app.setTab,
                labelType:
                    extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                indicatorColor: Brand.blush,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Image.asset('assets/mark.png', height: 56),
                ),
                destinations: [
                  for (final it in items)
                    NavigationRailDestination(
                      icon: it.$3 == 'Payments' && app.pending.isNotEmpty
                          ? Badge(label: Text('${app.pending.length}'), child: Icon(it.$1))
                          : Icon(it.$1),
                      selectedIcon: Icon(it.$2, color: Brand.accent),
                      label: Text(it.$3),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1, color: Brand.cardLine),
            Expanded(child: body),
          ],
        ),
      );
    });
  }
}
