// Design tokens — page Figma « 01 — Foundations & Design System ».
// Palette sémantique relevée dans Figma (ne pas modifier sans relecture design) :
// Canvas #fbfcff, Surface #ffffff, Texte principal #080d24, Texte secondaire
// #697087, Action principale #1c347a, Bleu marque #0d4d9e, Accent #248cff.
// Statuts : En attente entité #fff2d9, En attente studio #ebe8ff,
// Validée #e3f5f0, Refusée #fae5e5.
// Typographie Figma : titres Plus Jakarta Sans Bold/ExtraBold, texte et
// contrôles DM Sans. Les fichiers de ces polices ne sont pas livrés avec le
// projet (licence / ajout ultérieur) : l'app utilise la police système avec
// les mêmes graisses et tailles, documenté dans le README (écart assumé).
// Espacements Figma : 4 · 8 · 12 · 16 · 20 · 24 · 32 · 44 · 48 · 56.
// Rayons : cartes 20, champs 12, boutons 12, puces 999.
import 'package:flutter/material.dart';
import 'models.dart';

class AppColors {
  static const canvas = Color(0xFFFBFCFF);
  static const surface = Colors.white;
  static const ink = Color(0xFF080D24);
  static const secondary = Color(0xFF697087);
  static const primary = Color(0xFF1C347A);
  static const brandBlue = Color(0xFF0D4D9E);
  static const accent = Color(0xFF248CFF);
  static const gold = Color(0xFFC9A25E);
  static const navyOld = Color(0xFF0A1E3C); // compatibilité visuelle (QR, signature)
  static const muted = Color(0xFF697087);
  static const ok = Color(0xFF1E8A5A);
  static const warn = Color(0xFFB77900);
  static const err = Color(0xFFC0392B);
  static const entityBg = Color(0xFFFFF2D9);
  static const entityFg = Color(0xFF7A5A00);
  static const studioBg = Color(0xFFEBE8FF);
  static const studioFg = Color(0xFF3D2E9E);
  static const validatedBg = Color(0xFFE3F5F0);
  static const validatedFg = Color(0xFF146B4A);
  static const rejectedBg = Color(0xFFFAE5E5);
  static const rejectedFg = Color(0xFF9E2B2B);
  static const neutralBg = Color(0xFFEDEFF5);
  static const neutralFg = Color(0xFF4A5168);
  static const border = Color(0xFFDFE3F0);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    secondary: AppColors.accent,
    surface: AppColors.surface,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.canvas,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.canvas,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          color: AppColors.ink, fontSize: 20, fontWeight: FontWeight.w800),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: AppColors.primary),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.studioBg,
      labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
  );
}

/// Couleurs (fond, texte) d'une puce de statut, fidèles à la page 01 de Figma.
(Color, Color) statusChipColors(BookingStatus s) => switch (s) {
      BookingStatus.attenteEntite => (AppColors.entityBg, AppColors.entityFg),
      BookingStatus.attenteStudio => (AppColors.studioBg, AppColors.studioFg),
      BookingStatus.validee => (AppColors.validatedBg, AppColors.validatedFg),
      BookingStatus.refusee => (AppColors.rejectedBg, AppColors.rejectedFg),
      _ => (AppColors.neutralBg, AppColors.neutralFg),
    };

class StatusChip extends StatelessWidget {
  final BookingStatus status;
  const StatusChip(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = statusChipColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(status.label,
          style: TextStyle(
              color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

Widget starsRow(int rating, {double size = 15}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(i < rating ? Icons.star : Icons.star_border,
            size: size, color: AppColors.gold),
      ),
    );

/// Titre de section façon Figma (Plus Jakarta Sans Bold → graisse 800).
class SectionTitle extends StatelessWidget {
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionTitle(this.text, {super.key, this.actionLabel, this.onAction});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink)),
            ),
            if (actionLabel != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      );
}
