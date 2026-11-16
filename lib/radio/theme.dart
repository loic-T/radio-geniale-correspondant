import 'package:flutter/material.dart';

/// Couleurs reprises de style.css du site Radio Géniale.
class RgColors {
  static const Color fond = Color(0xFF5E0006); // --couleur-principale-fond
  static const Color fondSecondaire = Color(0xFF9B0F06); // --couleur-secondaire-fond
  static const Color fondTertiaire = Color(0xFFD53E0F); // --couleur-tertiaire-fond
  static const Color texte = Color(0xFFEED9B9); // --couleur-contraste-texte
  static const Color micOuvert = Color(0xFF7FFF00); // .unpressed
  static const Color micCoupe = Colors.red; // .pressed
}

ThemeData rgTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: RgColors.fondTertiaire,
    brightness: Brightness.dark,
  ).copyWith(
    primary: RgColors.texte,
    onPrimary: RgColors.fond,
    surface: RgColors.fond,
    onSurface: RgColors.texte,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: RgColors.fond,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: Colors.black45),
      labelStyle: const TextStyle(color: Colors.black54),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: RgColors.texte,
        foregroundColor: RgColors.fond,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: RgColors.fondSecondaire,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
  );
}
