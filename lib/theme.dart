import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Brand {
  static const accent = Color(0xFFC81E63);
  static const accentDark = Color(0xFF9C1249);
  static const cream = Color(0xFFFDF1E0);
  static const card = Color(0xFFFFF8EE);
  static const cardLine = Color(0xFFF3D9C2);
  static const blush = Color(0xFFFBDDD0);
  static const coral = Color(0xFFFF7A66);
  static const plum = Color(0xFF3A1230);
  static const plum2 = Color(0xFF4E1C43);
  static const ink = Color(0xFF2A1421);
  static const inkSoft = Color(0xFF4A3040);

  static TextStyle display(double size,
      {FontWeight weight = FontWeight.w600, Color color = ink, double? height}) {
    return GoogleFonts.fraunces(
        fontSize: size, fontWeight: weight, color: color, height: height);
  }

  static TextStyle body(double size,
      {FontWeight weight = FontWeight.w400, Color color = inkSoft, double? height}) {
    return GoogleFonts.dmSans(
        fontSize: size, fontWeight: weight, color: color, height: height);
  }
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.accent,
    brightness: Brightness.light,
  ).copyWith(
    primary: Brand.accent,
    onPrimary: Colors.white,
    secondary: Brand.coral,
    surface: Brand.cream,
    onSurface: Brand.ink,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Brand.cream,
  );
  return base.copyWith(
    textTheme: GoogleFonts.dmSansTextTheme(base.textTheme)
        .apply(bodyColor: Brand.ink, displayColor: Brand.ink),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        shape: const StadiumBorder(),
        side: const BorderSide(color: Brand.accent, width: 1.5),
        foregroundColor: Brand.accent,
        textStyle: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Brand.card,
      indicatorColor: Brand.blush,
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: Brand.ink),
      ),
    ),
  );
}

InputDecoration fieldDecoration(String label, {String? hint, String? helper}) {
  OutlineInputBorder border(Color c, [double w = 1.5]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    filled: true,
    fillColor: Colors.white,
    border: border(const Color(0xFFD9B9A6)),
    enabledBorder: border(const Color(0xFFD9B9A6)),
    focusedBorder: border(Brand.accent, 2),
  );
}
