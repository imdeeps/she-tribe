import 'package:flutter/foundation.dart';

/// Build-time settings, passed with --dart-define (see README).
class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Public website, used for the privacy policy link.
  static const siteUrl =
      String.fromEnvironment('SITE_URL', defaultValue: 'https://shetribe.example.com');

  /// Set true for App Store / Play Store builds. Store rules generally require
  /// their own billing for in-app digital memberships (and Apple names QR codes
  /// specifically), so in store builds the app does not sell memberships.
  /// Event tickets (a real-world event) are not affected.
  static const storeBuild = bool.fromEnvironment('STORE_BUILD');

  /// With no Supabase keys the app runs on sample data so you can click through it.
  static bool get isDemo => supabaseUrl.isEmpty || supabaseAnonKey.isEmpty;

  static bool get membershipPurchaseAllowed => kIsWeb || !storeBuild;

  /// Dummy sign-in code used in demo mode (and for test numbers on the server).
  static const demoCode = '123456';

  static String get privacyUrl => '$siteUrl/privacy.html';
}
