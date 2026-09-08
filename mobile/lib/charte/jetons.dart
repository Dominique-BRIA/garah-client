// ENGENDRÉ PAR charte/engendrer.mjs — NE PAS MODIFIER À LA MAIN.
//
// Toute correction se fait dans charte/jetons.json, puis :
//     node charte/engendrer.mjs
//
// Modifier ce fichier directement fait diverger le web et le mobile,
// et la prochaine exécution efface le changement sans prévenir.

import 'package:flutter/material.dart';

/// Les jetons de la charte GARAH, partagés avec l’application web.
abstract final class Jetons {
  static const marque = Color(0xFF12A594);
  static const primaire = Color(0xFF6366F1);
  static const primaireClair = Color(0xFF818CF8);
  static const primaireSombre = Color(0xFF4F46E5);
  static const accent = Color(0xFFAA3BFF);
  static const accentSecondaire = Color(0xFF3B82F6);
  static const succes = Color(0xFF10B981);
  static const alerte = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const info = Color(0xFF0EA5E9);

  // --- Thème clair ---
  static const clairFond = Color(0xFFF8FAFC);
  static const clairTexte = Color(0xFF0F172A);
  static const clairTexteAttenue = Color(0xFF64748B);
  static const clairSurface = Color(0xFFFFFFFF);
  static const clairSurfaceDouce = Color(0x0A0F172A);
  static const clairSurfaceDouceSurvol = Color(0xFFF1F5F9);
  static const clairVerreFond = Color(0xB3FFFFFF);
  static const clairVerreBordure = Color(0x8C94A3B8);
  // clairVerreOmbre : « 0 8px 32px rgba(15, 23, 42, 0.05) » n'est pas une couleur simple, à porter par le widget.
  static const clairChampFond = Color(0xCCFFFFFF);
  static const clairChampFondActif = Color(0xFFFFFFFF);
  static const clairChampBordure = Color(0x2E000000);

  // --- Thème sombre ---
  static const sombreFond = Color(0xFF0C0C14);
  static const sombreTexte = Color(0xFFF3F4F6);
  static const sombreTexteAttenue = Color(0xFF9CA3AF);
  static const sombreSurface = Color(0xFF12121E);
  static const sombreSurfaceDouce = Color(0x0DFFFFFF);
  static const sombreSurfaceDouceSurvol = Color(0xFF1A1A2E);
  static const sombreVerreFond = Color(0xBF12121E);
  static const sombreVerreBordure = Color(0x52AA3BFF);
  // sombreVerreOmbre : « 0 8px 32px rgba(0, 0, 0, 0.4) » n'est pas une couleur simple, à porter par le widget.
  static const sombreChampFond = Color(0x08FFFFFF);
  static const sombreChampFondActif = Color(0xF21A1A2A);
  static const sombreChampBordure = Color(0x2EFFFFFF);

  // --- Rayons ---
  static const rayonPetit = 8.0;
  static const rayonMoyen = 12.0;
  static const rayonGrand = 20.0;

  static const police = 'Outfit';

  /// En dessous, on rate le bouton une fois sur trois.
  static const cibleTactileMin = 44.0;
}
