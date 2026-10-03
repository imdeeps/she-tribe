import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'models.dart';

/// Everything the app needs from a server. Two implementations below:
/// [DemoBackend] (sample data, no accounts needed) and [SupabaseBackend].
abstract class Backend {
  String? get userId;
  Stream<void> get authChanges;

  /// [phone] is a full number such as +919876543210. The code arrives on WhatsApp.
  Future<void> sendCode(String phone);
  Future<void> verifyCode(String phone, String code);
  Future<void> signInDemo();
  Future<void> signOut();
  Future<void> deleteAccount();

  Future<Profile?> myProfile();
  Future<void> saveProfile(Profile p);
  Future<String?> myPhone();

  Future<List<TribeEvent>> events();
  Future<List<Registration>> myRegistrations();

  Future<List<Plan>> plans();
  Future<Membership?> myMembership();

  // Payments by UPI (Google Pay QR). The server decides the price; an admin
  // confirms each payment against the real UPI history.
  Future<PaymentSettings> paymentSettings();
  Future<List<PaymentRequest>> myPayments();
  Future<PaymentRequest> requestTicketPayment({required String eventId, required String tierId});
  Future<PaymentRequest> requestMembershipPayment(String planCode);
  Future<void> submitPayment({required String paymentId, required String utr});

  Future<bool> amIAdmin();
  Future<List<AdminPayment>> pendingPayments();
  Future<void> reviewPayment({required String paymentId, required bool approve});

  Future<List<Profile>> directory();
  Future<List<Post>> posts();
  Future<void> addPost({required String authorName, required String kind, required String text});

  Future<Commitment> myCommitment();
  Future<void> saveCommitment(Commitment c);
}

// ---------------------------------------------------------------------------
// Supabase (free tier) implementation
// ---------------------------------------------------------------------------

class SupabaseBackend implements Backend {
  SupabaseClient get _c => Supabase.instance.client;

  String get _uid {
    final id = _c.auth.currentUser?.id;
    if (id == null) throw Exception('Please sign in again.');
    return id;
  }

  @override
  String? get userId => _c.auth.currentUser?.id;

  @override
  Stream<void> get authChanges => _c.auth.onAuthStateChange.map((_) {});

  @override
  Future<void> sendCode(String phone) async {
    try {
      await _c.functions.invoke('send-otp', body: {'phone': phone});
    } on FunctionException catch (e) {
      throw Exception(_functionMessage(e));
    }
  }

  @override
  Future<void> verifyCode(String phone, String code) async {
    String? tokenHash;
    try {
      final res = await _c.functions
          .invoke('verify-otp', body: {'phone': phone, 'code': code});
      final data = res.data;
      if (data is Map && data['token_hash'] != null) {
        tokenHash = data['token_hash'].toString();
      }
    } on FunctionException catch (e) {
      throw Exception(_functionMessage(e));
    }
    if (tokenHash == null) throw Exception('Sign-in failed. Please try again.');
    await _c.auth.verifyOTP(tokenHash: tokenHash, type: OtpType.email);
  }

  @override
  Future<void> signInDemo() async {}

  @override
  Future<void> signOut() => _c.auth.signOut();

  @override
  Future<void> deleteAccount() async {
    try {
      await _c.functions.invoke('delete-account');
    } on FunctionException catch (e) {
      throw Exception(_functionMessage(e));
    }
    await _c.auth.signOut();
  }

  @override
  Future<Profile?> myProfile() async {
    final row = await _c.from('profiles').select().eq('id', _uid).maybeSingle();
    return row == null ? null : Profile.fromMap(row);
  }

  @override
  Future<void> saveProfile(Profile p) async {
    await _c.from('profiles').upsert(p.toMap());
  }

  @override
  Future<List<TribeEvent>> events() async {
    final rows = await _c
        .from('events')
        .select('*, ticket_tiers(*)')
        .eq('is_published', true)
        .order('starts_at', ascending: true);
    return [
      for (final r in rows) TribeEvent.fromMap(Map<String, dynamic>.from(r)),
    ];
  }

  @override
  Future<List<Registration>> myRegistrations() async {
    final rows = await _c.from('registrations').select().eq('user_id', _uid);
    return [
      for (final r in rows) Registration.fromMap(Map<String, dynamic>.from(r)),
    ];
  }

  String _functionMessage(FunctionException e) {
    final d = e.details;
    if (d is Map && d['error'] != null) return d['error'].toString();
    return 'Something went wrong. Please try again.';
  }

  @override
  Future<String?> myPhone() async {
    final row = await _c
        .from('phone_accounts')
        .select('phone')
        .eq('user_id', _uid)
        .maybeSingle();
    return row?['phone']?.toString();
  }

  @override
  Future<List<Plan>> plans() async {
    final rows = await _c.from('plans').select().order('sort', ascending: true);
    return [for (final r in rows) Plan.fromMap(Map<String, dynamic>.from(r))];
  }

  @override
  Future<Membership?> myMembership() async {
    final row =
        await _c.from('memberships').select().eq('user_id', _uid).maybeSingle();
    return row == null ? null : Membership.fromMap(row);
  }

  Future<T> _rpc<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  @override
  Future<PaymentSettings> paymentSettings() async {
    final row = await _c.from('payment_settings').select().limit(1).maybeSingle();
    return row == null
        ? const PaymentSettings(upiId: '')
        : PaymentSettings.fromMap(row);
  }

  @override
  Future<List<PaymentRequest>> myPayments() async {
    final rows = await _c
        .from('payments')
        .select()
        .eq('user_id', _uid)
        .order('created_at', ascending: false);
    return [
      for (final r in rows) PaymentRequest.fromMap(Map<String, dynamic>.from(r)),
    ];
  }

  @override
  Future<PaymentRequest> requestTicketPayment(
      {required String eventId, required String tierId}) {
    return _rpc(() async {
      final data = await _c.rpc('request_ticket_payment',
          params: {'p_event': eventId, 'p_tier': tierId});
      return PaymentRequest.fromMap(Map<String, dynamic>.from(data as Map));
    });
  }

  @override
  Future<PaymentRequest> requestMembershipPayment(String planCode) {
    return _rpc(() async {
      final data = await _c
          .rpc('request_membership_payment', params: {'p_plan': planCode});
      return PaymentRequest.fromMap(Map<String, dynamic>.from(data as Map));
    });
  }

  @override
  Future<void> submitPayment({required String paymentId, required String utr}) {
    return _rpc(() async {
      await _c.rpc('submit_payment', params: {'p_payment': paymentId, 'p_utr': utr});
    });
  }

  @override
  Future<bool> amIAdmin() async {
    final row =
        await _c.from('admins').select('user_id').eq('user_id', _uid).maybeSingle();
    return row != null;
  }

  @override
  Future<List<AdminPayment>> pendingPayments() {
    return _rpc(() async {
      final rows = await _c.rpc('list_pending_payments');
      return [
        for (final r in (rows as List))
          AdminPayment.fromMap(Map<String, dynamic>.from(r as Map)),
      ];
    });
  }

  @override
  Future<void> reviewPayment({required String paymentId, required bool approve}) {
    return _rpc(() async {
      await _c.rpc('review_payment',
          params: {'p_payment': paymentId, 'p_approve': approve});
    });
  }

  @override
  Future<List<Profile>> directory() async {
    final rows = await _c
        .from('profiles')
        .select()
        .eq('directory_opt_in', true)
        .neq('id', _uid);
    return [for (final r in rows) Profile.fromMap(Map<String, dynamic>.from(r))];
  }

  @override
  Future<List<Post>> posts() async {
    final rows = await _c
        .from('posts')
        .select()
        .order('created_at', ascending: false)
        .limit(60);
    return [for (final r in rows) Post.fromMap(Map<String, dynamic>.from(r))];
  }

  @override
  Future<void> addPost({
    required String authorName,
    required String kind,
    required String text,
  }) async {
    await _c.from('posts').insert({
      'user_id': _uid,
      'author_name': authorName,
      'kind': kind,
      'text': text,
    });
  }

  @override
  Future<Commitment> myCommitment() async {
    final row =
        await _c.from('commitments').select().eq('user_id', _uid).maybeSingle();
    if (row == null) return const Commitment();
    final picks = row['picks'];
    return Commitment(
      picks: picks is List ? picks.map((e) => e.toString()).toList() : <String>[],
      goal: (row['goal'] ?? '').toString(),
    );
  }

  @override
  Future<void> saveCommitment(Commitment c) async {
    await _c.from('commitments').upsert({
      'user_id': _uid,
      'picks': c.picks,
      'goal': c.goal.trim(),
    });
  }
}

// ---------------------------------------------------------------------------
// Demo implementation: no server needed, resets when the app restarts.
// ---------------------------------------------------------------------------

class DemoBackend implements Backend {
  String? _uid;
  String? _phone;
  Profile? _profile;
  Membership? _membership;
  final List<PaymentRequest> _payments = [];
  int _refCounter = 0;
  Commitment _commitment = const Commitment();
  final List<Registration> _regs = [];

  final List<Post> _posts = [
    Post(
      id: 'p1',
      userId: 'x1',
      authorName: 'Sample member',
      kind: 'need',
      text: 'Looking for a photographer for a small product shoot.',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    Post(
      id: 'p2',
      userId: 'x2',
      authorName: 'Sample member',
      kind: 'offer',
      text: 'Happy to help with branding feedback for early-stage founders.',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  final List<Profile> _members = const [
    Profile(
      id: 'm1',
      fullName: 'Sample Member One',
      businessName: 'Home bakery',
      stage: 'started',
      roleTag: 'Entrepreneur',
      lookingFor: ['Customers', 'Collaborations'],
      about: 'Exploring corporate gifting orders.',
      directoryOptIn: true,
    ),
    Profile(
      id: 'm2',
      fullName: 'Sample Member Two',
      stage: 'idea',
      roleTag: 'Aspiring Entrepreneur',
      lookingFor: ['Mentorship', 'Ideas'],
      about: 'Working on a business idea and looking for guidance.',
      directoryOptIn: true,
    ),
  ];

  @override
  String? get userId => _uid;

  @override
  Stream<void> get authChanges => Stream<void>.empty();

  @override
  Future<void> sendCode(String phone) async {
    _phone = phone; // demo: no WhatsApp message is sent
  }

  @override
  Future<void> verifyCode(String phone, String code) async {
    if (code.trim() != Config.demoCode) {
      throw Exception('That code is not right.');
    }
    _phone = phone;
    _uid = 'demo-user';
  }

  @override
  Future<void> signInDemo() async {
    _phone = '+919999900000';
    _uid = 'demo-user';
  }

  @override
  Future<void> signOut() async {
    _uid = null;
  }

  @override
  Future<void> deleteAccount() async {
    _uid = null;
    _profile = null;
    _membership = null;
    _regs.clear();
    _payments.clear();
  }

  @override
  Future<Profile?> myProfile() async => _profile;

  @override
  Future<void> saveProfile(Profile p) async => _profile = p;

  @override
  Future<String?> myPhone() async => _phone;

  @override
  Future<List<TribeEvent>> events() async => const [
        TribeEvent(
          id: 'e1',
          title: 'SHE TRIBE: The First Circle',
          subtitle: 'For women who dream. Women who build. Women who grow.',
          description:
              'An intimate, interactive meet-up for women who are building, growing or dreaming of building something of their own. You do not need a business to belong.',
          highlights: [
            'Who\u2019s in the room?',
            '60-second SHE intro',
            'Idea to Business conversation',
            'The SHE TRIBE Hot Seat',
            'Collaboration Circle',
            'Ask & Offer wall',
            'Networking bingo',
            'Commitment card',
          ],
          venue: 'Venue to be announced \u00B7 Chennai',
          capacity: 50,
          tiers: [
            TicketTier(
              id: 't1',
              name: 'Early Bird',
              priceInr: 499,
              perks: ['Entry to the First Circle', 'Welcome gift', 'SHE TRIBE card'],
            ),
            TicketTier(
              id: 't2',
              name: 'Regular',
              priceInr: 799,
              perks: ['Entry to the First Circle', 'Welcome gift', 'SHE TRIBE card'],
            ),
            TicketTier(
              id: 't3',
              name: 'Premium',
              priceInr: 1499,
              perks: [
                'Professional headshot',
                '5-minute business spotlight',
                'Priority networking',
                'Business directory listing',
              ],
            ),
          ],
        ),
      ];

  @override
  Future<List<Registration>> myRegistrations() async => List.of(_regs);

  @override
  Future<List<Plan>> plans() async => const [
        Plan(
          code: 'member',
          name: 'She Tribe Member',
          tagline: 'Monthly networking and member-only perks',
          priceInr: 1499,
          interval: 'year',
          perks: [
            'Monthly networking',
            'Member directory',
            'Member-only workshops',
            'Collaboration opportunities',
            'Discounts',
            'Business spotlights',
          ],
        ),
        Plan(
          code: 'circle',
          name: 'She Tribe Circle',
          tagline: 'Small-group depth and curated introductions',
          priceInr: 3999,
          interval: 'year',
          perks: [
            'Everything in Member',
            'Small-group mastermind',
            'Monthly accountability',
            'Expert sessions',
            'Business clinics',
            'Curated introductions',
          ],
        ),
      ];

  @override
  Future<Membership?> myMembership() async => _membership;

  @override
  Future<PaymentSettings> paymentSettings() async => const PaymentSettings(
        upiId: 'demo@upi',
        payeeName: 'She Tribe (demo)',
      );

  @override
  Future<List<PaymentRequest>> myPayments() async => List.of(_payments);

  PaymentRequest _newPayment({
    required String kind,
    String? registrationId,
    String? planCode,
    required String label,
    required int amount,
  }) {
    for (var i = 0; i < _payments.length; i++) {
      final p = _payments[i];
      if (p.status == 'awaiting' &&
          p.kind == kind &&
          p.registrationId == registrationId &&
          p.planCode == planCode &&
          p.amountInr == amount) {
        return p;
      }
    }
    _refCounter++;
    final p = PaymentRequest(
      id: 'pay$_refCounter',
      kind: kind,
      registrationId: registrationId,
      planCode: planCode,
      label: label,
      amountInr: amount,
      reference: 'ST-DEMO${_refCounter.toString().padLeft(2, '0')}',
      status: 'awaiting',
      createdAt: DateTime.now(),
    );
    _payments.insert(0, p);
    return p;
  }

  void _setPayment(String id, PaymentRequest Function(PaymentRequest) change) {
    final i = _payments.indexWhere((p) => p.id == id);
    if (i >= 0) _payments[i] = change(_payments[i]);
  }

  PaymentRequest _copy(PaymentRequest p, {String? status, String? utr}) =>
      PaymentRequest(
        id: p.id,
        kind: p.kind,
        registrationId: p.registrationId,
        planCode: p.planCode,
        label: p.label,
        amountInr: p.amountInr,
        reference: p.reference,
        status: status ?? p.status,
        utr: utr ?? p.utr,
        createdAt: p.createdAt,
      );

  @override
  Future<PaymentRequest> requestTicketPayment(
      {required String eventId, required String tierId}) async {
    final e = (await events()).firstWhere((x) => x.id == eventId);
    final t = e.tiers.firstWhere((x) => x.id == tierId);
    if (_regs.any((r) => r.eventId == eventId && r.isPaid)) {
      throw Exception('You are already registered for this event.');
    }
    _regs.removeWhere((r) => r.eventId == eventId);
    final reg = Registration(
      id: 'r${_regs.length + 1}',
      eventId: eventId,
      tierId: tierId,
      status: 'pending',
      amountInr: t.priceInr,
    );
    _regs.add(reg);
    return _newPayment(
      kind: 'ticket',
      registrationId: reg.id,
      label: '${e.title} - ${t.name}',
      amount: t.priceInr,
    );
  }

  @override
  Future<PaymentRequest> requestMembershipPayment(String planCode) async {
    final plan = (await plans()).firstWhere((p) => p.code == planCode);
    return _newPayment(
      kind: 'membership',
      planCode: planCode,
      label: plan.name,
      amount: plan.priceInr,
    );
  }

  @override
  Future<void> submitPayment({required String paymentId, required String utr}) async {
    final clean = utr.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^[0-9]{12}$').hasMatch(clean)) {
      throw Exception('Enter the 12-digit UPI transaction ID shown in your payment app.');
    }
    _setPayment(paymentId, (p) => _copy(p, status: 'submitted', utr: clean));
  }

  // In demo mode you are your own admin, so you can see the full flow.
  @override
  Future<bool> amIAdmin() async => true;

  @override
  Future<List<AdminPayment>> pendingPayments() async => [
        for (final p in _payments.where((p) => p.status == 'submitted'))
          AdminPayment(
            id: p.id,
            reference: p.reference,
            label: p.label,
            kind: p.kind,
            amountInr: p.amountInr,
            utr: p.utr ?? '',
            payerName: _profile?.fullName ?? 'Demo member',
            payerPhone: _phone ?? '',
            submittedAt: p.createdAt,
          ),
      ];

  @override
  Future<void> reviewPayment({required String paymentId, required bool approve}) async {
    final p = _payments.firstWhere((x) => x.id == paymentId);
    _setPayment(paymentId, (x) => _copy(x, status: approve ? 'approved' : 'rejected'));
    if (!approve) return;
    if (p.kind == 'ticket') {
      final i = _regs.indexWhere((r) => r.id == p.registrationId);
      if (i >= 0) {
        final r = _regs[i];
        _regs[i] = Registration(
          id: r.id,
          eventId: r.eventId,
          tierId: r.tierId,
          status: 'paid',
          amountInr: r.amountInr,
        );
      }
    } else {
      final base = (_membership?.currentEnd != null &&
              _membership!.currentEnd!.isAfter(DateTime.now()))
          ? _membership!.currentEnd!
          : DateTime.now();
      _membership = Membership(
        planCode: p.planCode ?? 'member',
        status: 'active',
        currentEnd: base.add(const Duration(days: 365)),
      );
    }
  }

  @override
  Future<List<Profile>> directory() async =>
      (_membership?.isActive ?? false) ? _members : <Profile>[];

  @override
  Future<List<Post>> posts() async => List.of(_posts);

  @override
  Future<void> addPost({
    required String authorName,
    required String kind,
    required String text,
  }) async {
    _posts.insert(
      0,
      Post(
        id: 'p${_posts.length + 1}',
        userId: _uid ?? 'demo-user',
        authorName: authorName,
        kind: kind,
        text: text,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<Commitment> myCommitment() async => _commitment;

  @override
  Future<void> saveCommitment(Commitment c) async => _commitment = c;
}
