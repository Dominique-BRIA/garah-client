import 'package:flutter/material.dart';

import 'jetons.dart';

/// Les deux thèmes de GARAH, dérivés des jetons de la charte.
///
/// ## ⚠️ Aucune couleur n'est écrite ici
///
/// Tout vient de [Jetons], engendré depuis `charte/jetons.json`. Écrire un
/// `Color(0xFF...)` dans ce fichier ferait diverger le mobile du web sans que
/// rien ne le signale — et une marque qui n'a pas la même couleur d'un écran à
/// l'autre cesse d'être une marque.
///
/// ## Le clair est le défaut, comme sur le web
///
/// Une boutique se regarde comme une vitrine : photos sur fond clair, prix en
/// noir sur blanc. Suivre le réglage du système donnerait le sombre à tout
/// téléphone réglé ainsi — c'est-à-dire beaucoup — et la boutique n'aurait
/// jamais l'air de ce qu'on a dessiné.
abstract final class ThemeGarah {
  static ThemeData get clair => _construire(
    clair: true,
    fond: Jetons.clairFond,
    surface: Jetons.clairSurface,
    texte: Jetons.clairTexte,
    texteAttenue: Jetons.clairTexteAttenue,
    bordure: Jetons.clairVerreBordure,
    champFond: Jetons.clairChampFond,
    champBordure: Jetons.clairChampBordure,
  );

  static ThemeData get sombre => _construire(
    clair: false,
    fond: Jetons.sombreFond,
    surface: Jetons.sombreSurface,
    texte: Jetons.sombreTexte,
    texteAttenue: Jetons.sombreTexteAttenue,
    bordure: Jetons.sombreVerreBordure,
    champFond: Jetons.sombreChampFond,
    champBordure: Jetons.sombreChampBordure,
  );

  static ThemeData _construire({
    required bool clair,
    required Color fond,
    required Color surface,
    required Color texte,
    required Color texteAttenue,
    required Color bordure,
    required Color champFond,
    required Color champBordure,
  }) {
    final schema = ColorScheme(
      brightness: clair ? Brightness.light : Brightness.dark,
      primary: Jetons.primaire,
      onPrimary: Colors.white,
      secondary: Jetons.marque,
      onSecondary: Colors.white,
      error: Jetons.danger,
      onError: Colors.white,
      surface: surface,
      onSurface: texte,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: schema.brightness,
      colorScheme: schema,
      scaffoldBackgroundColor: fond,

      // ⚠️ `fontFamily` reste NUL tant que les fichiers de police ne sont pas
      //    dans le dépôt. Nommer « Outfit » sans l'embarquer ne lève aucune
      //    erreur : Flutter retombe silencieusement sur la police système, et
      //    on croit voir la charte alors qu'on voit Roboto.
      fontFamily: null,

      appBarTheme: AppBarTheme(
        backgroundColor: fond,
        foregroundColor: texte,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: texte,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Jetons.rayonMoyen),
          side: BorderSide(color: bordure),
        ),
        margin: EdgeInsets.zero,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Jetons.primaire,
          foregroundColor: Colors.white,
          // 🎯 44 px de haut MINIMUM. En dessous, on rate le bouton une fois
          //    sur trois — et sur un écran de commande, rater signifie
          //    recommencer.
          minimumSize: const Size(0, Jetons.cibleTactileMin),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Jetons.rayonPetit),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: texte,
          minimumSize: const Size(0, Jetons.cibleTactileMin),
          side: BorderSide(color: bordure),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Jetons.rayonPetit),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Jetons.primaire,
          minimumSize: const Size(0, Jetons.cibleTactileMin),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: champFond,
        // ⚠️ 16 px minimum sur un champ de saisie : en dessous, iOS zoome à la
        //    mise au point et l'utilisateur se retrouve avec une page agrandie
        //    qu'il doit repincer.
        hintStyle: TextStyle(color: texteAttenue, fontSize: 16),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Jetons.rayonPetit),
          borderSide: BorderSide(color: champBordure),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Jetons.rayonPetit),
          borderSide: BorderSide(color: champBordure),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Jetons.rayonPetit),
          borderSide: const BorderSide(color: Jetons.primaire, width: 1.6),
        ),
      ),

      // ⚠️ L'ONGLET ACTIF EST VERT, sur une pastille verte très pâle.
      //
      //    Le défaut de Material 3 posait une pastille pleine dans la couleur
      //    du conteneur, avec une icône BLANCHE dessus : sur un onglet
      //    sélectionné, on ne voyait plus l'icône, seulement une tache. C'est
      //    l'inverse de ce qu'une barre de navigation doit faire — dire OÙ l'on
      //    est sans effacer ce qu'on regarde.
      //
      //    Le vert est celui de la marque, le même que le GAR de l'accueil et
      //    que la calebasse : c'est la couleur qui dit « GARAH », et l'endroit
      //    où l'on se trouve dans GARAH est un bon endroit pour la poser.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: Jetons.marque.withValues(alpha: 0.14),
        // Un rectangle bien arrondi plutôt que la gélule par défaut : il
        // couvre l'icône ET le libellé, ce qui donne la sensation d'une touche
        // survolée plutôt que d'une bulle posée derrière un dessin.
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Jetons.rayonMoyen),
        ),
        elevation: 0,
        height: 66,
        iconTheme: WidgetStateProperty.resolveWith(
          (etats) => IconThemeData(
            size: 23,
            color: etats.contains(WidgetState.selected)
                ? Jetons.marque
                : texteAttenue,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (etats) => TextStyle(
            fontSize: 11,
            fontWeight: etats.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: etats.contains(WidgetState.selected)
                ? Jetons.marque
                : texteAttenue,
          ),
        ),
      ),

      dividerTheme: DividerThemeData(color: bordure, thickness: 1, space: 1),

      textTheme: Typography.material2021(
        platform: TargetPlatform.android,
      ).black.apply(bodyColor: texte, displayColor: texte),
    );
  }
}

/// Les couleurs qui dépendent du thème mais que Material ne porte pas.
///
/// `Theme.of(context).colorScheme` ne connaît ni « texte atténué » ni « surface
/// douce ». Les recalculer dans chaque widget donnerait vingt nuances de gris
/// légèrement différentes.
extension CouleursGarah on BuildContext {
  bool get estSombre => Theme.of(this).brightness == Brightness.dark;

  Color get texteAttenue =>
      estSombre ? Jetons.sombreTexteAttenue : Jetons.clairTexteAttenue;

  Color get bordure =>
      estSombre ? Jetons.sombreVerreBordure : Jetons.clairVerreBordure;

  Color get surfaceDouce =>
      estSombre ? Jetons.sombreSurfaceDouce : Jetons.clairSurfaceDouce;
}
