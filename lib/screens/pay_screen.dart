import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_state.dart';
import '../config.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Pay by scanning a UPI QR with Google Pay (or any UPI app), then enter the
/// mobile number so the She Tribe team can confirm it.
class PayScreen extends StatefulWidget {
  const PayScreen({super.key, required this.paymentId});

  final String paymentId;

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  final _phone = TextEditingController();
  bool _busy = false;
  bool _wa = true;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _copy(String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) snack(context, '$what copied');
  }

  Future<void> _openUpiApp(String link) async {
    try {
      await openUrl(link);
    } catch (_) {
      if (mounted) {
        snack(context,
            'Could not open a UPI app. Scan the QR from another phone, or copy the UPI ID and pay manually.');
      }
    }
  }

  Future<void> _submit(AppState app, PaymentRequest pay) async {
    final clean = cleanIndianMobile(_phone.text);
    if (clean == null) {
      setState(() => _error = 'Enter the 10-digit mobile number you paid from.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Is this number right?'),
        content: Text(
            'We\u2019ll look for a payment from ${formatMobile(clean)}. Please use the number you paid from.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Edit')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Yes, that\u2019s right')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await app.submitPayment(pay.id, clean);
      if (_wa) {
        try {
          await app.saveWhatsapp(clean);
        } catch (_) {
          // The payment is already submitted; a failed WhatsApp save should not block it.
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editPhone(AppState app, PaymentRequest pay) async {
    final c = TextEditingController(text: pay.payerPhone ?? '');
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit your mobile number'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(12),
          ],
          decoration: fieldDecoration('Your 10-digit mobile number', hint: '98765 43210'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(c.text), child: const Text('Save')),
        ],
      ),
    );
    if (v == null) return;
    try {
      await app.updatePaymentPhone(pay.id, v);
      if (mounted) snack(context, 'Mobile number updated');
    } catch (e) {
      if (mounted) snack(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final pay = app.paymentById(widget.paymentId);
    final settings = app.paymentSettings;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Brand.cream,
        foregroundColor: Brand.ink,
        title: const Text('Pay with UPI'),
      ),
      body: pay == null
          ? const Center(child: Text('This payment is no longer available.'))
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  children: [
                    Text(pay.label,
                        style: Brand.body(16, weight: FontWeight.w600, color: Brand.inkSoft)),
                    const SizedBox(height: 4),
                    Text(formatInr(pay.amountInr),
                        style: Brand.display(44, weight: FontWeight.w700, color: Brand.accent)),
                    const SizedBox(height: 20),
                    ..._body(app, pay, settings),
                  ],
                ),
              ),
            ),
    );
  }

  List<Widget> _body(AppState app, PaymentRequest pay, PaymentSettings settings) {
    switch (pay.status) {
      case 'approved':
        return [
          _statusCard(Icons.check_circle, 'Payment confirmed',
              'Thank you! You\u2019re all set.'),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
        ];
      case 'submitted':
        return [
          _statusCard(
            Icons.hourglass_top,
            'We\u2019re confirming your payment',
            'We check each payment against our UPI history. Your ticket or membership turns on as soon as it matches. Pull down on the app to refresh.',
          ),
          const SizedBox(height: 12),
          Text('Reference ${pay.reference} \u00B7 Paid from ${formatMobile(pay.payerPhone ?? '')}',
              style: Brand.body(14)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => _editPhone(app, pay),
              child: Text('Wrong number? Edit my number',
                  style: Brand.body(14, color: Brand.accent, weight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back to the app')),
          ..._support(settings),
        ];
      case 'rejected':
        return [
          _statusCard(
            Icons.error_outline,
            'We couldn\u2019t confirm this payment',
            'We couldn\u2019t match it to our UPI history. If money left your account, please message us with the mobile number you paid from.',
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back')),
          ..._support(settings),
        ];
      case 'cancelled':
        return [
          _statusCard(Icons.info_outline, 'This payment was replaced',
              'Please go back and start again.'),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back')),
        ];
      default:
        return _awaiting(app, pay, settings);
    }
  }

  List<Widget> _awaiting(AppState app, PaymentRequest pay, PaymentSettings settings) {
    if (!settings.isConfigured) {
      return [
        _statusCard(Icons.construction, 'Payments aren\u2019t set up yet',
            'The She Tribe team hasn\u2019t added a UPI ID yet. Please check back soon.'),
      ];
    }
    final link = upiLink(settings, pay);

    return [
      SoftCard(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: link,
                version: QrVersions.auto,
                size: 230,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Scan with Google Pay, PhonePe, Paytm or any UPI app. The amount and note are filled in for you.',
              textAlign: TextAlign.center,
              style: Brand.body(14, height: 1.45),
            ),
            if (settings.payeeName.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'You\u2019ll see the name ${settings.payeeName.trim()} in your UPI app. That\u2019s the right place to pay.',
                textAlign: TextAlign.center,
                style: Brand.body(14, weight: FontWeight.w700, color: Brand.ink, height: 1.4),
              ),
            ],
          ],
        ),
      ),
      if (!kIsWeb) ...[
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _openUpiApp(link),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open my UPI app'),
        ),
        const SizedBox(height: 4),
        Text(
          'Paying from this same phone? If your app refuses the button, use the UPI ID below.',
          textAlign: TextAlign.center,
          style: Brand.body(13, height: 1.4),
        ),
      ],
      const SizedBox(height: 16),
      SoftCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _copyRow('UPI ID', settings.upiId, () => _copy(settings.upiId, 'UPI ID')),
            const Divider(height: 20, color: Brand.cardLine),
            _copyRow('Amount', formatInr(pay.amountInr), () => _copy('${pay.amountInr}', 'Amount')),
            const Divider(height: 20, color: Brand.cardLine),
            _copyRow('Note / remark', pay.reference, () => _copy(pay.reference, 'Note')),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Text('After you pay', style: Brand.display(22)),
      const SizedBox(height: 6),
      Text(
        'Enter the 10-digit mobile number you paid from, so we can match your payment. We\u2019ll also use it to send you your ticket updates.',
        style: Brand.body(15, height: 1.5),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumberNational],
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(12),
        ],
        decoration: fieldDecoration('Your 10-digit mobile number', hint: '98765 43210'),
        onSubmitted: (_) => _busy ? null : _submit(app, pay),
      ),
      CheckboxListTile(
        value: _wa,
        onChanged: (v) => setState(() => _wa = v ?? true),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
        title: Text('Also send my ticket and event updates to this number on WhatsApp',
            style: Brand.body(14, weight: FontWeight.w600, color: Brand.ink, height: 1.35)),
      ),
      const SizedBox(height: 4),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, size: 16, color: Brand.accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Used only to match your payment and send ticket updates. We never share it or send spam.',
              style: Brand.body(13, height: 1.4),
            ),
          ),
        ],
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!,
            style: Brand.body(14, color: const Color(0xFFB3123F), weight: FontWeight.w600)),
      ],
      const SizedBox(height: 14),
      FilledButton(
        onPressed: _busy ? null : () => _submit(app, pay),
        child: Text(_busy ? 'Sending...' : 'I\u2019ve paid'),
      ),
      if (Config.isDemo)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            'Demo mode: no real payment happens. Type any Indian mobile number (for example 9876543210), then approve it in the Admin tab.',
            style: Brand.body(13, height: 1.4),
          ),
        ),
      ..._support(settings),
    ];
  }

  List<Widget> _support(PaymentSettings settings) {
    if (settings.supportWhatsapp.trim().isEmpty) return const [];
    final digits = settings.supportWhatsapp.replaceAll(RegExp(r'\D'), '');
    return [
      TextButton(
        onPressed: () => openUrl('https://wa.me/$digits'),
        child: const Text('Need help? Message us on WhatsApp'),
      ),
    ];
  }

  Widget _copyRow(String label, String value, VoidCallback onCopy) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Brand.body(13, weight: FontWeight.w600)),
              const SizedBox(height: 2),
              SelectableText(value,
                  style: Brand.body(17, weight: FontWeight.w700, color: Brand.ink)),
            ],
          ),
        ),
        IconButton(
          onPressed: onCopy,
          tooltip: 'Copy',
          icon: const Icon(Icons.copy, color: Brand.accent),
        ),
      ],
    );
  }

  Widget _statusCard(IconData icon, String title, String text) {
    return SoftCard(
      color: Brand.blush,
      borderColor: Brand.blush,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Brand.accent, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Brand.display(21, weight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(text, style: Brand.body(15, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
