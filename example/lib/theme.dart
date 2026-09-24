import 'package:flutter/cupertino.dart';

// ---------------------------------------------------------------------------
// Colour palette — mirrors website/src/styles/custom.css (dark theme).
// ---------------------------------------------------------------------------

/// Background navy.
const kColorBackground = Color(0xFF0B1020);

/// Nav / tab bar background.
const kColorBarBackground = Color(0xFF0D1226);

/// Surface / cards.
const kColorSurface = Color(0xFF1C2033);

/// Hairline / dividers.
const kColorHairline = Color(0xFF333850);

/// Primary text.
const kColorTextPrimary = Color(0xFFECEEF4);

/// Secondary / muted text.
const kColorTextSecondary = Color(0xFF8A90A4);

/// Accent orange (#ff9a3c).
const kColorAccent = Color(0xFFFF9A3C);

/// Coral / favourite heart (#ff5e62).
const kColorCoral = Color(0xFFFF5E62);

/// Gradient start (orange).
const kColorGradientStart = Color(0xFFFFB347);

/// Gradient end (coral).
const kColorGradientEnd = Color(0xFFFF5E62);

/// Avatar / hero gradient.
const kAvatarGradient = LinearGradient(
  colors: [kColorGradientStart, kColorGradientEnd],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Dark Cupertino theme for the whole app.
CupertinoThemeData slingTheme() => const CupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: kColorAccent,
      scaffoldBackgroundColor: kColorBackground,
      barBackgroundColor: kColorBarBackground,
      textTheme: CupertinoTextThemeData(primaryColor: kColorTextPrimary),
    );
