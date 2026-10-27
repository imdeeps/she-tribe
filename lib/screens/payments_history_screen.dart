import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Admin only: every payment members have made, newest first, with the date
/// and time each one was submitted and decided.
class PaymentsHistoryScreen extends StatefulWidget {
  const PaymentsHistoryScreen({super.key});

  @override
  State<PaymentsHistoryScreen> createState() => _PaymentsHistoryScreenState();
}

class _PaymentsHistoryScreenState extends State<PaymentsHistoryScreen> {
  List<AdminPayment>? _all;
  String? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await context.read<AppState>().loadAllPayments();
      if (mounted) setState(() { _all = rows; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    }
  }

  static const _filters = {
    'all': 'All',
    'approved': 'Approved',
    'submitted': 'To check',
    'rejected': 'Rejected',
  };

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final shown = all == null
        ? <AdminPayment>[]
        : [for (final p in all) if (_filter == 'all' || p.status == _filter) p];
    final approved = [for (final p in all ?? <AdminPayment>[]) if (p.status == 'approved') p];
    final total = approved.fold<int>(0, (a, p) => a + p.amountInr);

    return Scaffold(
      backgroundColor: Brand.cream,
      appBar: AppBar(title: const Text('All payments')),
      body: PageScroll(
        title: 'Payment history',
        subtitle: 'Every payment members have submitted, newest first.',
        onRefresh: _load,
        children: [
          if (_error != null)
            SoftCard(child: Text(_error!, style: Brand.body(15, color: Brand.accent)))
          else if (all == null)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else ...[
            SoftCard(
              child: Row(
                children: [
                  Expanded(child: _stat('Approved total', formatInr(total))),
                  Expanded(child: _stat('Approved payments', '${approved.length}')),
                  Expanded(child: _stat('All entries', '${all.length}')),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _filters.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _filter == e.key,
                    onSelected: (_) => setState(() => _filter = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (shown.isEmpty)
              SoftCard(child: Text('No payments here yet.', style: Brand.body(16))),
            for (final p in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(formatInr(p.amountInr),
                                style: Brand.display(26, weight: FontWeight.w700, color: Brand.accent)),
                          ),
                          _statusTag(p.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(p.payerName.isEmpty ? p.payerPhone : p.payerName,
                          style: Brand.body(16, weight: FontWeight.w700, color: Brand.ink)),
                      Text(p.label, style: Brand.body(14)),
                      const SizedBox(height: 6),
                      _line('Contact', p.payerPhone),
                      _line('Paid on', p.submittedAt == null ? '-' : formatDate(p.submittedAt)),
                      if (p.decidedAt != null)
                        _line(p.status == 'rejected' ? 'Rejected on' : 'Approved on',
                            formatDate(p.decidedAt)),
                      _line('Transaction ID', p.utr.isEmpty ? '-' : p.utr),
                      _line('Reference', p.reference),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Brand.display(24, weight: FontWeight.w700, color: Brand.ink)),
          Text(label, style: Brand.body(13)),
        ],
      );

  Widget _statusTag(String s) {
    switch (s) {
      case 'approved':
        return const Tag('Approved', bg: Color(0xFFE3F3E6), fg: Color(0xFF1E6B34));
      case 'rejected':
        return const Tag('Rejected', bg: Color(0xFFFBE4E4), fg: Color(0xFF9B1C1C));
      default:
        return const Tag('To check');
    }
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 120, child: Text(label, style: Brand.body(14, weight: FontWeight.w600))),
            Expanded(child: SelectableText(value, style: Brand.body(15, color: Brand.ink))),
          ],
        ),
      );
}
