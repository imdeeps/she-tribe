import 'package:flutter_test/flutter_test.dart';
import 'package:she_tribe/models.dart';

void main() {
  test('formatInr uses Indian digit grouping', () {
    expect(formatInr(499), '\u20B9499');
    expect(formatInr(1499), '\u20B91,499');
    expect(formatInr(125000), '\u20B91,25,000');
  });

  test('membership stays active until the paid period ends after cancelling', () {
    final future = Membership(
      planCode: 'member',
      status: 'cancelled',
      currentEnd: DateTime.now().add(const Duration(days: 10)),
    );
    final past = Membership(
      planCode: 'member',
      status: 'cancelled',
      currentEnd: DateTime.now().subtract(const Duration(days: 1)),
    );
    expect(future.isActive, isTrue);
    expect(past.isActive, isFalse);
  });

  test('UPI link carries the UPI ID, amount, and the reference as the note', () {
    const settings = PaymentSettings(upiId: 'shetribe@okhdfcbank', payeeName: 'She Tribe');
    final pay = PaymentRequest(
      id: '1',
      kind: 'ticket',
      label: 'The First Circle - Early Bird',
      amountInr: 499,
      reference: 'ST-4K9Q2M',
      status: 'awaiting',
      createdAt: DateTime(2026, 10, 3),
    );
    expect(
      upiLink(settings, pay),
      'upi://pay?pa=shetribe@okhdfcbank&pn=She%20Tribe&am=499.00&cu=INR&tn=ST-4K9Q2M',
    );
  });

  test('placeholder UPI ID is treated as not set up', () {
    expect(const PaymentSettings(upiId: 'REPLACE-ME@upi').isConfigured, isFalse);
    expect(const PaymentSettings(upiId: '').isConfigured, isFalse);
    expect(const PaymentSettings(upiId: 'shetribe@okhdfcbank').isConfigured, isTrue);
  });

  test('mobile numbers are cleaned to 10 digits', () {
    expect(cleanIndianMobile('98765 43210'), '9876543210');
    expect(cleanIndianMobile('+91 98765-43210'), '9876543210');
    expect(cleanIndianMobile('09876543210'), '9876543210');
    expect(cleanIndianMobile('12345'), isNull);
    expect(cleanIndianMobile('5876543210'), isNull);
  });
}
