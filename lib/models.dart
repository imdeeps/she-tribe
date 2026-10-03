/// Labels taken from the She Tribe launch plan.
const stageLabels = <String, String>{
  'idea': 'I have an idea',
  'started': 'I have started',
  'growing': 'I am growing',
};

const roleOptions = <String>[
  'Founder',
  'Entrepreneur',
  'Aspiring Entrepreneur',
  'Freelancer',
  'Professional',
];

const lookingForOptions = <String>[
  'Collaborations',
  'Customers',
  'Mentorship',
  'Ideas',
  'Connections',
  'Learning',
];

const commitmentOptions = <String>[
  'Launch my page',
  'Talk to my first customer',
  'Register my business',
  'Create my offer',
  'Meet 3 new people',
  'Start posting',
  'Take the first step',
];

List<String> _strings(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : <String>[];

class Profile {
  final String id;
  final String fullName;
  final String businessName;
  final String stage;
  final String roleTag;
  final List<String> lookingFor;
  final String about;
  final String instagram;
  final bool directoryOptIn;

  const Profile({
    required this.id,
    this.fullName = '',
    this.businessName = '',
    this.stage = 'idea',
    this.roleTag = 'Aspiring Entrepreneur',
    this.lookingFor = const [],
    this.about = '',
    this.instagram = '',
    this.directoryOptIn = false,
  });

  bool get isComplete => fullName.trim().isNotEmpty;

  String get firstName {
    final t = fullName.trim();
    return t.isEmpty ? '' : t.split(' ').first;
  }

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'].toString(),
        fullName: (m['full_name'] ?? '').toString(),
        businessName: (m['business_name'] ?? '').toString(),
        stage: (m['stage'] ?? 'idea').toString(),
        roleTag: (m['role_tag'] ?? 'Aspiring Entrepreneur').toString(),
        lookingFor: _strings(m['looking_for']),
        about: (m['about'] ?? '').toString(),
        instagram: (m['instagram'] ?? '').toString(),
        directoryOptIn: m['directory_opt_in'] == true,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'full_name': fullName.trim(),
        'business_name': businessName.trim(),
        'stage': stage,
        'role_tag': roleTag,
        'looking_for': lookingFor,
        'about': about.trim(),
        'instagram': instagram.trim(),
        'directory_opt_in': directoryOptIn,
      };

  Profile copyWith({bool? directoryOptIn}) => Profile(
        id: id,
        fullName: fullName,
        businessName: businessName,
        stage: stage,
        roleTag: roleTag,
        lookingFor: lookingFor,
        about: about,
        instagram: instagram,
        directoryOptIn: directoryOptIn ?? this.directoryOptIn,
      );
}

class TicketTier {
  final String id;
  final String name;
  final int priceInr;
  final int? memberPriceInr;
  final List<String> perks;
  final int? seats;

  const TicketTier({
    required this.id,
    required this.name,
    required this.priceInr,
    this.memberPriceInr,
    this.perks = const [],
    this.seats,
  });

  factory TicketTier.fromMap(Map<String, dynamic> m) => TicketTier(
        id: m['id'].toString(),
        name: (m['name'] ?? '').toString(),
        priceInr: (m['price_inr'] as num?)?.toInt() ?? 0,
        memberPriceInr: (m['member_price_inr'] as num?)?.toInt(),
        perks: _strings(m['perks']),
        seats: (m['seats'] as num?)?.toInt(),
      );
}

class TribeEvent {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final List<String> highlights;
  final DateTime? startsAt;
  final String venue;
  final int? capacity;
  final List<TicketTier> tiers;

  const TribeEvent({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.description = '',
    this.highlights = const [],
    this.startsAt,
    this.venue = '',
    this.capacity,
    this.tiers = const [],
  });

  factory TribeEvent.fromMap(Map<String, dynamic> m) {
    final tiers = (m['ticket_tiers'] is List)
        ? (m['ticket_tiers'] as List)
            .map((e) => TicketTier.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList()
        : <TicketTier>[];
    tiers.sort((a, b) => a.priceInr.compareTo(b.priceInr));
    return TribeEvent(
      id: m['id'].toString(),
      title: (m['title'] ?? '').toString(),
      subtitle: (m['subtitle'] ?? '').toString(),
      description: (m['description'] ?? '').toString(),
      highlights: _strings(m['highlights']),
      startsAt: m['starts_at'] == null
          ? null
          : DateTime.tryParse(m['starts_at'].toString())?.toLocal(),
      venue: (m['venue'] ?? '').toString(),
      capacity: (m['capacity'] as num?)?.toInt(),
      tiers: tiers,
    );
  }
}

class Registration {
  final String id;
  final String eventId;
  final String tierId;
  final String status; // pending | paid | cancelled
  final int amountInr;

  const Registration({
    required this.id,
    required this.eventId,
    required this.tierId,
    required this.status,
    required this.amountInr,
  });

  bool get isPaid => status == 'paid';

  factory Registration.fromMap(Map<String, dynamic> m) => Registration(
        id: m['id'].toString(),
        eventId: m['event_id'].toString(),
        tierId: m['tier_id'].toString(),
        status: (m['status'] ?? 'pending').toString(),
        amountInr: (m['amount_inr'] as num?)?.toInt() ?? 0,
      );
}

class Plan {
  final String code;
  final String name;
  final String tagline;
  final int priceInr;
  final String interval; // year | month
  final List<String> perks;

  const Plan({
    required this.code,
    required this.name,
    required this.tagline,
    required this.priceInr,
    required this.interval,
    this.perks = const [],
  });

  factory Plan.fromMap(Map<String, dynamic> m) => Plan(
        code: m['code'].toString(),
        name: (m['name'] ?? '').toString(),
        tagline: (m['tagline'] ?? '').toString(),
        priceInr: (m['price_inr'] as num?)?.toInt() ?? 0,
        interval: (m['interval'] ?? 'year').toString(),
        perks: _strings(m['perks']),
      );
}

class Membership {
  final String planCode;
  final String status; // active | cancelled | expired
  final DateTime? currentEnd;

  const Membership({
    required this.planCode,
    required this.status,
    this.currentEnd,
  });

  bool get isActive {
    if (status == 'active') return true;
    if (status == 'cancelled' && currentEnd != null) {
      return currentEnd!.isAfter(DateTime.now());
    }
    return false;
  }

  factory Membership.fromMap(Map<String, dynamic> m) => Membership(
        planCode: m['plan_code'].toString(),
        status: (m['status'] ?? 'expired').toString(),
        currentEnd: m['current_end'] == null
            ? null
            : DateTime.tryParse(m['current_end'].toString())?.toLocal(),
      );
}

class Post {
  final String id;
  final String userId;
  final String authorName;
  final String kind; // need | offer
  final String text;
  final DateTime createdAt;

  const Post({
    required this.id,
    required this.userId,
    required this.authorName,
    required this.kind,
    required this.text,
    required this.createdAt,
  });

  factory Post.fromMap(Map<String, dynamic> m) => Post(
        id: m['id'].toString(),
        userId: m['user_id'].toString(),
        authorName: (m['author_name'] ?? 'Member').toString(),
        kind: (m['kind'] ?? 'need').toString(),
        text: (m['text'] ?? '').toString(),
        createdAt:
            DateTime.tryParse((m['created_at'] ?? '').toString())?.toLocal() ??
                DateTime.now(),
      );
}

class Commitment {
  final List<String> picks;
  final String goal;
  const Commitment({this.picks = const [], this.goal = ''});
}

String formatInr(int amount) {
  final s = amount.toString();
  if (s.length <= 3) return '\u20B9$s';
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '\u20B9${parts.join(',')},$last3';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String formatDate(DateTime? d) {
  if (d == null) return 'Date to be announced';
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final mm = d.minute.toString().padLeft(2, '0');
  final ap = d.hour >= 12 ? 'PM' : 'AM';
  return '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year} \u00B7 $h12:$mm $ap';
}

String formatShortDate(DateTime d) =>
    '${d.day} ${_months[d.month - 1]} ${d.year}';


class PaymentSettings {
  final String upiId;
  final String payeeName;
  final String supportWhatsapp;

  const PaymentSettings({
    required this.upiId,
    this.payeeName = 'She Tribe',
    this.supportWhatsapp = '',
  });

  /// False until you replace the placeholder UPI ID in the database.
  bool get isConfigured =>
      upiId.contains('@') && !upiId.toUpperCase().contains('REPLACE');

  factory PaymentSettings.fromMap(Map<String, dynamic> m) => PaymentSettings(
        upiId: (m['upi_id'] ?? '').toString(),
        payeeName: (m['payee_name'] ?? 'She Tribe').toString(),
        supportWhatsapp: (m['support_whatsapp'] ?? '').toString(),
      );
}

class PaymentRequest {
  final String id;
  final String kind; // ticket | membership
  final String? registrationId;
  final String? planCode;
  final String label;
  final int amountInr;
  final String reference;
  final String status; // awaiting | submitted | approved | rejected | cancelled
  final String? utr;
  final DateTime createdAt;

  const PaymentRequest({
    required this.id,
    required this.kind,
    this.registrationId,
    this.planCode,
    required this.label,
    required this.amountInr,
    required this.reference,
    required this.status,
    this.utr,
    required this.createdAt,
  });

  bool get isOpen => status == 'awaiting' || status == 'submitted';

  factory PaymentRequest.fromMap(Map<String, dynamic> m) => PaymentRequest(
        id: m['id'].toString(),
        kind: (m['kind'] ?? 'ticket').toString(),
        registrationId: m['registration_id']?.toString(),
        planCode: m['plan_code']?.toString(),
        label: (m['label'] ?? '').toString(),
        amountInr: (m['amount_inr'] as num?)?.toInt() ?? 0,
        reference: (m['reference'] ?? '').toString(),
        status: (m['status'] ?? 'awaiting').toString(),
        utr: m['utr']?.toString(),
        createdAt:
            DateTime.tryParse((m['created_at'] ?? '').toString())?.toLocal() ??
                DateTime.now(),
      );
}

/// A payment waiting for the admin to check it against the bank/UPI history.
class AdminPayment {
  final String id;
  final String reference;
  final String label;
  final String kind;
  final int amountInr;
  final String utr;
  final String payerName;
  final String payerPhone;
  final DateTime? submittedAt;

  const AdminPayment({
    required this.id,
    required this.reference,
    required this.label,
    required this.kind,
    required this.amountInr,
    required this.utr,
    required this.payerName,
    required this.payerPhone,
    this.submittedAt,
  });

  factory AdminPayment.fromMap(Map<String, dynamic> m) => AdminPayment(
        id: m['id'].toString(),
        reference: (m['reference'] ?? '').toString(),
        label: (m['label'] ?? '').toString(),
        kind: (m['kind'] ?? '').toString(),
        amountInr: (m['amount_inr'] as num?)?.toInt() ?? 0,
        utr: (m['utr'] ?? '').toString(),
        payerName: (m['payer_name'] ?? '').toString(),
        payerPhone: (m['payer_phone'] ?? '').toString(),
        submittedAt: m['submitted_at'] == null
            ? null
            : DateTime.tryParse(m['submitted_at'].toString())?.toLocal(),
      );
}

/// The UPI link inside the QR code. Scanning it (or tapping it on a phone)
/// opens Google Pay / PhonePe / Paytm with the amount and note filled in.
String upiLink(PaymentSettings s, PaymentRequest p) {
  final pn = Uri.encodeComponent(s.payeeName);
  final tn = Uri.encodeComponent(p.reference);
  return 'upi://pay?pa=${s.upiId}&pn=$pn&am=${p.amountInr}.00&cu=INR&tn=$tn';
}

/// Turns what someone types into a 10-digit Indian mobile number, or null.
String? cleanIndianMobile(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  var d = digits;
  if (d.length == 12 && d.startsWith('91')) d = d.substring(2);
  if (d.length == 11 && d.startsWith('0')) d = d.substring(1);
  if (d.length == 10 && RegExp(r'^[6-9]').hasMatch(d)) return d;
  return null;
}
