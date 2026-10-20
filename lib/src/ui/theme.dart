import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// Dodate's look: a clean white page (near-black in dark mode), one spruce
// accent, amber (never red) for "needs more time", and one colour per
// assignment so its pieces are easy to follow across the week. Big
// Bricolage Grotesque headings, Figtree for everything else.

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
    required this.accentShadow,
    required this.warn,
    required this.warnInk,
    required this.warnBg,
    required this.warnBtn,
    required this.warnBar,
    required this.danger,
    required this.dangerBg,
    required this.chipOn,
    required this.chipOnInk,
    required this.disabled,
    required this.glass,
    required this.navOn,
    required this.navShadow,
    required this.scrim,
    required this.toastAccent,
    required this.tints,
  });

  final Color bg, surface, surfaceAlt, ink, muted, line;
  final Color accent, onAccent, accentSoft, accentShadow;
  final Color warn, warnInk, warnBg, warnBtn, warnBar, danger, dangerBg;
  final Color chipOn, chipOnInk, disabled, glass, navOn, navShadow, scrim, toastAccent;
  final List<Tint> tints;

  static const light = DodateColors(
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF1F2EF),
    ink: Color(0xFF121614),
    muted: Color(0xFF646C67),
    line: Color(0xFFECEEEA),
    accent: Color(0xFF1F6F5C),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0x1A1F6F5C),
    accentShadow: Color(0x4D1F6F5C),
    warn: Color(0xFF8A5A12),
    warnInk: Color(0xFF6B440B),
    warnBg: Color(0xFFFBF1DE),
    warnBtn: Color(0xFFF3DFB6),
    warnBar: Color(0xFFE0A93F),
    danger: Color(0xFF9A3434),
    dangerBg: Color(0xFFF8E3E1),
    chipOn: Color(0xFF121614),
    chipOnInk: Color(0xFFFFFFFF),
    disabled: Color(0xFFC2C7C3),
    glass: Color(0xC7FFFFFF),
    navOn: Color(0x12121614),
    navShadow: Color(0x1A121614),
    scrim: Color(0x66121614),
    toastAccent: Color(0xFF6BCBAA),
    tints: [
      Tint(Color(0xFFE3ECF9), Color(0xFF1F5FBF)),
      Tint(Color(0xFFF8E7D9), Color(0xFFC25E00)),
      Tint(Color(0xFFECE5F8), Color(0xFF7A4FC8)),
      Tint(Color(0xFFF2EDD9), Color(0xFF957000)),
      Tint(Color(0xFFF8E3EC), Color(0xFFC2457E)),
      Tint(Color(0xFFDFEEF0), Color(0xFF287C8A)),
    ],
  );

  static const dark = DodateColors(
    bg: Color(0xFF0F1211),
    surface: Color(0xFF0F1211),
    surfaceAlt: Color(0xFF202522),
    ink: Color(0xFFECEFED),
    muted: Color(0xFF9AA39E),
    line: Color(0xFF232826),
    accent: Color(0xFF6BCBAA),
    onAccent: Color(0xFF0B1A15),
    accentSoft: Color(0x1F6BCBAA),
    accentShadow: Color(0x66000000),
    warn: Color(0xFFEDC27A),
    warnInk: Color(0xFFF2D6A2),
    warnBg: Color(0xFF33291A),
    warnBtn: Color(0xFF4A3B22),
    warnBar: Color(0xFFD9A549),
    danger: Color(0xFFF0A3A0),
    dangerBg: Color(0xFF3C2222),
    chipOn: Color(0xFFECEFED),
    chipOnInk: Color(0xFF0F1211),
    disabled: Color(0xFF4A524D),
    glass: Color(0xC71E2321),
    navOn: Color(0x1FFFFFFF),
    navShadow: Color(0x73000000),
    scrim: Color(0x99000000),
    toastAccent: Color(0xFF1F6F5C),
    tints: [
      Tint(Color(0xFF1D2A3D), Color(0xFF7FA9F0)),
      Tint(Color(0xFF3A2A1C), Color(0xFFF0A060)),
      Tint(Color(0xFF2B2540), Color(0xFFB79CF2)),
      Tint(Color(0xFF353019), Color(0xFFE2C25A)),
      Tint(Color(0xFF3D2430), Color(0xFFF09AC0)),
      Tint(Color(0xFF1B3236), Color(0xFF6FC3D1)),
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

/// Bricolage heading styles from the design.
class Styles {
  static TextStyle display(Color c) =>
      TextStyle(fontFamily: displayFont, fontWeight: FontWeight.w800, fontSize: 40, height: 44 / 40, letterSpacing: -1.2, color: c);
  static TextStyle h2(Color c) =>
      TextStyle(fontFamily: displayFont, fontWeight: FontWeight.w800, fontSize: 28, height: 32 / 28, letterSpacing: -0.8, color: c);
  static TextStyle h3(Color c) =>
      TextStyle(fontFamily: displayFont, fontWeight: FontWeight.w700, fontSize: 20, height: 24 / 20, color: c);
  static TextStyle kicker(Color c) =>
      TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w700, letterSpacing: 1, color: c);
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

  return base.copyWith(
    scaffoldBackgroundColor: c.bg,
    extensions: [c],
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textTheme: base.textTheme
        .apply(bodyColor: c.ink, displayColor: c.ink)
        .copyWith(
          displaySmall: Styles.display(c.ink),
          headlineSmall: Styles.h2(c.ink),
          titleLarge: Styles.h3(c.ink),
          titleMedium: TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w600, color: c.ink),
          bodyMedium: TextStyle(fontSize: 16, color: c.ink, height: 1.5),
          bodySmall: TextStyle(fontSize: 14, color: c.muted, height: 20 / 14),
          labelLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
    }),
    dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceAlt,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: c.muted),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.accent,
        textStyle: const TextStyle(fontFamily: bodyFont, fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: c.scrim,
      showDragHandle: true,
      dragHandleColor: brightness == Brightness.dark ? const Color(0xFF3A403D) : c.line,
      dragHandleSize: const Size(40, 4),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      titleTextStyle: Styles.h3(c.ink),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      dayForegroundColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? c.chipOnInk : s.contains(WidgetState.disabled) ? c.disabled : c.ink),
      dayBackgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.chipOn : null),
      todayForegroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.chipOnInk : c.accent),
      todayBorder: BorderSide(color: c.accent, width: 2),
    ),
    timePickerTheme: TimePickerThemeData(backgroundColor: c.bg),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.accent,
      linearTrackColor: c.surfaceAlt,
      linearMinHeight: 6,
      borderRadius: BorderRadius.circular(6),
    ),
  );
}
