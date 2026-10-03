import 'dart:async';

import 'package:flutter/foundation.dart';

import 'backend.dart';
import 'models.dart';

enum AppStage { loading, signedOut, needsProfile, ready }

class AppState extends ChangeNotifier {
  AppState(this.backend);

  final Backend backend;
  StreamSubscription<void>? _sub;
  bool _loading = false;

  AppStage stage = AppStage.loading;
  Profile? profile;
  List<TribeEvent> events = [];
  List<Registration> registrations = [];
  List<Plan> plans = [];
  Membership? membership;
  List<Post> posts = [];
  List<Profile> directory = [];
  Commitment commitment = const Commitment();
  PaymentSettings paymentSettings = const PaymentSettings(upiId: '');
  List<PaymentRequest> payments = [];
  List<AdminPayment> pending = [];
  bool isAdmin = false;
  String? phone;
  int tab = 0;
  String? error;

  bool get isMember => membership?.isActive ?? false;

  Registration? registrationFor(String eventId) {
    for (final r in registrations) {
      if (r.eventId == eventId && r.status != 'cancelled') return r;
    }
    return null;
  }

  /// The payment still being worked on for a ticket, if any.
  PaymentRequest? openPaymentForRegistration(String registrationId) {
    for (final p in payments) {
      if (p.registrationId == registrationId && p.isOpen) return p;
    }
    return null;
  }

  /// True if the last payment attempt for this ticket was turned down.
  bool lastPaymentRejected(String registrationId) {
    for (final p in payments) {
      if (p.registrationId == registrationId) return p.status == 'rejected';
    }
    return false;
  }

  PaymentRequest? openMembershipPayment(String planCode) {
    for (final p in payments) {
      if (p.kind == 'membership' && p.planCode == planCode && p.isOpen) return p;
    }
    return null;
  }

  PaymentRequest? paymentById(String id) {
    for (final p in payments) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> init() async {
    _sub = backend.authChanges.listen((_) => load());
    await load();
  }

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    try {
      if (backend.userId == null) {
        stage = AppStage.signedOut;
      } else {
        profile = await backend.myProfile();
        if (profile == null || !profile!.isComplete) {
          stage = AppStage.needsProfile;
        } else {
          await _loadData();
          stage = AppStage.ready;
        }
      }
      error = null;
    } catch (e) {
      error = _clean(e);
      if (stage == AppStage.loading) {
        stage = backend.userId == null ? AppStage.signedOut : AppStage.ready;
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadData() async {
    final r = await Future.wait<Object?>([
      backend.events(),
      backend.myRegistrations(),
      backend.plans(),
      backend.myMembership(),
      backend.posts(),
      backend.directory(),
      backend.myCommitment(),
      backend.myPayments(),
      backend.paymentSettings(),
      backend.amIAdmin(),
      backend.myPhone(),
    ]);
    events = r[0] as List<TribeEvent>;
    registrations = r[1] as List<Registration>;
    plans = r[2] as List<Plan>;
    membership = r[3] as Membership?;
    posts = r[4] as List<Post>;
    directory = r[5] as List<Profile>;
    commitment = r[6] as Commitment;
    payments = r[7] as List<PaymentRequest>;
    paymentSettings = r[8] as PaymentSettings;
    isAdmin = r[9] as bool;
    phone = r[10] as String?;
    pending = isAdmin ? await backend.pendingPayments() : <AdminPayment>[];
  }

  /// Pull-to-refresh and when returning from the payment page.
  Future<void> refresh() async {
    if (stage != AppStage.ready) return;
    try {
      await _loadData();
      error = null;
    } catch (e) {
      error = _clean(e);
    }
    notifyListeners();
  }

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');

  void setTab(int i) {
    tab = i;
    notifyListeners();
  }

  Future<void> sendCode(String phone) => backend.sendCode(phone);

  Future<void> verifyCode(String phone, String code) async {
    await backend.verifyCode(phone, code);
    await load();
  }

  Future<void> signInDemo() async {
    await backend.signInDemo();
    await load();
  }

  Future<void> saveProfile(Profile p) async {
    await backend.saveProfile(p);
    profile = p;
    await _loadData();
    stage = AppStage.ready;
    notifyListeners();
  }

  Future<void> signOut() async {
    await backend.signOut();
    _reset();
  }

  Future<void> deleteAccount() async {
    await backend.deleteAccount();
    _reset();
  }

  void _reset() {
    profile = null;
    events = [];
    registrations = [];
    membership = null;
    posts = [];
    directory = [];
    commitment = const Commitment();
    payments = [];
    pending = [];
    isAdmin = false;
    phone = null;
    tab = 0;
    stage = AppStage.signedOut;
    notifyListeners();
  }

  Future<PaymentRequest> requestTicketPayment(String eventId, String tierId) async {
    final p = await backend.requestTicketPayment(eventId: eventId, tierId: tierId);
    await refresh();
    return p;
  }

  Future<PaymentRequest> requestMembershipPayment(String planCode) async {
    final p = await backend.requestMembershipPayment(planCode);
    await refresh();
    return p;
  }

  Future<void> submitPayment(String paymentId, String utr) async {
    await backend.submitPayment(paymentId: paymentId, utr: utr);
    await refresh();
  }

  Future<void> reviewPayment(String paymentId, bool approve) async {
    await backend.reviewPayment(paymentId: paymentId, approve: approve);
    await refresh();
  }

  Future<void> addPost(String kind, String text) async {
    await backend.addPost(
      authorName: profile?.fullName ?? 'Member',
      kind: kind,
      text: text,
    );
    posts = await backend.posts();
    notifyListeners();
  }

  Future<void> setDirectoryOptIn(bool value) async {
    final p = profile;
    if (p == null) return;
    final updated = p.copyWith(directoryOptIn: value);
    await backend.saveProfile(updated);
    profile = updated;
    notifyListeners();
  }

  Future<void> saveCommitment(Commitment c) async {
    await backend.saveCommitment(c);
    commitment = c;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
