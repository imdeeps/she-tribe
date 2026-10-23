import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import 'common.dart';

/// A gentle, optional ask for a WhatsApp number. Shown only when we do not
/// have one yet, and the member can always say "Not now".
class WhatsappAsk extends StatefulWidget {
  final String title;
  final String body;
  const WhatsappAsk({super.key, required this.title, required this.body});

  @override
  State<WhatsappAsk> createState() => _WhatsappAskState();
}

class _WhatsappAskState extends State<WhatsappAsk> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  bool _dismissed = false;
  bool _saved = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final mobile = cleanIndianMobile(_ctrl.text);
    if (mobile == null) {
      setState(() => _error = 'Please enter a 10-digit mobile number.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppState>().saveWhatsapp(mobile);
      if (mounted) setState(() => _saved = true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (_dismissed) return const SizedBox.shrink();
    if (_saved) {
      return SoftCard(
        color: Brand.blush,
        borderColor: Brand.blush,
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Brand.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Lovely, we’ll keep you posted on WhatsApp.',
                  style: Brand.body(15, weight: FontWeight.w600, color: Brand.ink)),
            ),
          ],
        ),
      );
    }
    if (app.whatsapp != null && app.whatsapp!.isNotEmpty) {
      return const SizedBox.shrink();
    }
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: Brand.display(20, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(widget.body, style: Brand.body(15, height: 1.5)),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            enabled: !_busy,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: fieldDecoration(
              'WhatsApp number (optional)',
              hint: '98765 43210',
              helper:
                  'Only for She Tribe event updates and your bookings. No spam, and you can ask us to stop any time.',
            ).copyWith(prefixText: '+91  '),
            onSubmitted: (_) => _save(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: Brand.body(14, color: const Color(0xFFB3123F), weight: FontWeight.w600)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Saving...' : 'Yes, keep me posted'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _busy ? null : () => setState(() => _dismissed = true),
                child: const Text('Not now'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
