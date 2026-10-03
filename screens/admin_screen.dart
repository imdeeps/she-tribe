import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Only shown to admins. Check each payment against your Google Pay history,
/// then approve or reject it.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String? _busyId;

  Future<void> _review(AppState app, AdminPayment p, bool approve) async {
    if (!approve) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reject this payment?'),
          content: Text(
              'Reject ${formatInr(p.amountInr)} from ${p.payerName.isEmpty ? p.payerPhone : p.payerName}? They will be asked to try again or contact you.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Reject')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _busyId = p.id);
    try {
      await app.reviewPayment(p.id, approve);
      if (mounted) snack(context, approve ? 'Approved' : 'Rejected');
    } catch (e) {
      if (mounted) snack(context, errorText(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return PageScroll(
      title: 'Payments to check',
      subtitle:
          'Open Google Pay, find the payment with the same amount and transaction ID, then approve it here.',
      onRefresh: app.refresh,
      children: [
        if (app.pending.isEmpty)
          SoftCard(
            child: Text('Nothing waiting. New payments appear here once members submit their transaction ID.',
                style: Brand.body(16, height: 1.5)),
          ),
        for (final p in app.pending)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(formatInr(p.amountInr),
                            style: Brand.display(30, weight: FontWeight.w700, color: Brand.accent)),
                      ),
                      Tag(p.kind == 'ticket' ? 'Ticket' : 'Membership'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(p.label, style: Brand.body(16, weight: FontWeight.w600, color: Brand.ink)),
                  const SizedBox(height: 10),
                  _line('Name', p.payerName.isEmpty ? 'Not set' : p.payerName),
                  _line('WhatsApp', p.payerPhone),
                  _line('Transaction ID', p.utr),
                  _line('Note on payment', p.reference),
                  if (p.submittedAt != null) _line('Submitted', formatDate(p.submittedAt)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _busyId == p.id ? null : () => _review(app, p, true),
                          child: Text(_busyId == p.id ? 'Working...' : 'Approve'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busyId == p.id ? null : () => _review(app, p, false),
                          child: const Text('Reject'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: Brand.body(14, weight: FontWeight.w600))),
          Expanded(child: SelectableText(value, style: Brand.body(15, color: Brand.ink))),
        ],
      ),
    );
  }
}
