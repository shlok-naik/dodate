import 'package:flutter/material.dart';

// Dodate's look: calm, warm minimalism. A sage-tinted paper background, one
// spruce accent, amber (never red) for "needs attention", and a soft colour
// per assignment so its stages are easy to follow across the week.

const displayFont = 'Bricolage';
const bodyFont = 'Figtree';

/// A soft background + readable foreground pair for one assignment.
class Tint {
  const Tint(this.bg, this.fg);
  final Color bg;
  final Color fg;
}

class DodateColors extends ThemeExtension<DodateColors> {
  const DodateColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.muted,
    required this.line,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.warn,
    required this.warnBg,
    required this.danger,
    required this.dangerBg,
    required this.tints,
  });

  final Color bg, surface, surfaceAlt, ink, muted, line;
  final Color accent, onAccent, accentSoft;
  final Color warn, warnBg, danger, dangerBg;
  final List<Tint> tints;

  static const light = DodateColors(
    bg: Color(0xFFF5F6F2),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFECEEE8),
    ink: Color(0xFF1D2420),
    muted: Color(0xFF66706A),
    line: Color(0xFFDFE3DC),
    accent: Color(0xFF1F6F5C),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFDCEDE6),
    warn: Color(0xFF7D5210),
    warnBg: Color(0xFFFBEFD8),
    danger: Color(0xFF9A3434),
    dangerBg: Color(0xFFF8E3E1),
    tints: [
      Tint(Color(0xFFDDE8FA), Color(0xFF2D4E8A)),
      Tint(Color(0xFFD6EFE2), Color(0xFF25674B)),
      Tint(Color(0xFFFBE2D2), Color(0xFF8A4A22)),
      Tint(Color(0xFFE6DFFA), Color(0xFF55418F)),
      Tint(Color(0xFFF6ECC2), Color(0xFF6E5B12)),
      Tint(Color(0xFFF7DCE3), Color(0xFF8A3550)),
    ],
  );

  static const dark = DodateColors(
    bg: Color(0xFF111513),
    surface: Color(0xFF1A1F1C),
    surfaceAlt: Color(0xFF232925),
    ink: Color(0xFFE6EBE7),
    muted: Color(0xFF9BA59F),
    line: Color(0xFF2C332E),
    accent: Color(0xFF62C4A5),
    onAccent: Color(0xFF0D1F19),
    accentSoft: Color(0xFF1E3A31),
    warn: Color(0xFFEDC27A),
    warnBg: Color(0xFF3A2F1A),
    danger: Color(0xFFF0A3A0),
    dangerBg: Color(0xFF3C2222),
    tints: [
      Tint(Color(0xFF22314A), Color(0xFFA9C3F0)),
      Tint(Color(0xFF1F3A2E), Color(0xFF9EDBBE)),
      Tint(Color(0xFF45301F), Color(0xFFF2BE98)),
      Tint(Color(0xFF302A4A), Color(0xFFC9B9F5)),
      Tint(Color(0xFF3D3619), Color(0xFFE8D58A)),
      Tint(Color(0xFF45242E), Color(0xFFF0AFC0)),
    ],
  );

  /// Stable colour for an assignment, derived from its id.
  Tint tintFor(String id) => tints[id.codeUnits.fold(0, (a, c) => a + c) % tints.length];

  @override
  DodateColors copyWith() => this;

  @override
  DodateColors lerp(ThemeExtension<DodateColors>? other, double t) =>
      t < 0.5 || other is! DodateColors ? this : other;
}

extension DodateTheme on BuildContext {
  DodateColors get colors => Theme.of(this).extension<DodateColors>()!;
}

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? DodateColors.dark : DodateColors.light;
  final scheme = ColorScheme.fromSeed(seedColor: c.accent, brightness: brightness).copyWith(
    primary: c.accent,
    onPrimary: c.onAccent,
    primaryContainer: c.accentSoft,
    surface: c.surface,
    onSurface: c.ink,
    onSurfaceVariant: c.muted,
    outline: c.line,
    outlineVariant: c.line,
    error: c.danger,
  );

  final base = ThemeData(useMaterial3: true, brightness: brightness, colorScheme: scheme, fontFamily: bodyFont);
  TextStyle display(double size) =>
      TextStyle(fontFamily: displayFont, fontSize: size, fontWeight: FontWeight.w700, color: c.ink, height: 1.1);

  return base.copyWith(
    scaffoldBackgroundColor: c.bg,
    extensions: [c],
    textTheme: base.textTheme
        .apply(bodyColor: c.ink, displayColor: c.ink)
        .copyWith(
          displaySmall: display(34),
          headlineSmall: display(24),
          titleLarge: display(20),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.ink),
          bodyMedium: TextStyle(fontSize: 15, color: c.ink, height: 1.35),
          bodySmall: TextStyle(fontSize: 13, color: c.muted, height: 1.35),
          labelLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: display(22),
    ),
    dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceAlt,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: c.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontFamily: bodyFont, fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.accent,
        textStyle: const TextStyle(fontFamily: bodyFont, fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.accent,
      foregroundColor: c.onAccent,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      extendedTextStyle: const TextStyle(fontFamily: bodyFont, fontSize: 16, fontWeight: FontWeight.w600),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: c.line,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: display(22),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surface,
      selectedColor: c.accent,
      side: BorderSide(color: c.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: TextStyle(fontFamily: bodyFont, fontSize: 14, fontWeight: FontWeight.w600, color: c.ink),
      secondaryLabelStyle: TextStyle(fontFamily: bodyFont, fontSize: 14, fontWeight: FontWeight.w600, color: c.onAccent),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.accent,
      linearTrackColor: c.surfaceAlt,
      linearMinHeight: 6,
      borderRadius: BorderRadius.circular(6),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.ink,
      contentTextStyle: TextStyle(fontFamily: bodyFont, color: c.bg, fontSize: 15),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
