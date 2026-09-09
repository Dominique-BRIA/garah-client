import 'package:flutter/material.dart';

/// L'écran d'ouverture, tenu quelques instants.
///
/// ## 🎯 Il PROLONGE l'écran natif, il ne le remplace pas
///
/// Android affiche `launch_background.xml` dès le lancement du processus, et
/// le retire dès que Flutter dessine sa première image. Cette application
/// n'attend rien au démarrage — trois lectures locales, aucun appel réseau
/// bloquant — si bien que la marque apparaissait et disparaissait dans le même
/// battement de cils.
///
/// Cet écran reprend **exactement** le dessin du natif : mêmes couleurs, même
/// symbole, même taille. La couture est donc invisible, et l'ouverture donne
/// l'impression d'un seul écran tenu, non de deux qui se succèdent.
///
/// ## ⚠️ Ce que ça coûte, et pourquoi c'est acceptable
///
/// Une attente **délibérée** est du temps pris à quelqu'un. Un écran
/// d'ouverture existe normalement pour couvrir un chargement ; ici il n'y a
/// rien à couvrir, et la retenue est purement une affaire de marque.
///
/// D'où [tenue] à 900 ms : assez pour lire le logo, trop court pour agacer.
/// Au-delà d'une seconde et demie, l'ouverture est ressentie comme lente —
/// et une application lente au lancement passe pour lente tout court.
///
/// ⚠️ Le fondu est ce qui rend la chose supportable : sans lui, l'écran
///    disparaît d'un coup et la coupure se voit. Il commence AVANT la fin de
///    la tenue, de sorte que la première image de l'application est déjà là
///    quand la marque achève de s'effacer.
class Ouverture extends StatefulWidget {
  const Ouverture({super.key, required this.suite});

  /// Ce qui s'affiche une fois la marque effacée.
  final Widget suite;

  /// Combien de temps la marque reste pleinement visible.
  static const Duration tenue = Duration(milliseconds: 900);

  /// La durée de l'effacement.
  static const Duration fondu = Duration(milliseconds: 350);

  /// Le fond, en clair et en sombre.
  ///
  /// ⚠️ Ces deux valeurs sont recopiées de `android/app/src/main/res` —
  ///    `values/couleurs.xml` et `values-night/couleurs.xml`. Android lit ces
  ///    fichiers avant que Dart n'existe : la charte ne peut pas les porter.
  ///    Si l'une des deux change, celle d'ici change AUSSI, sinon la couture
  ///    entre l'écran natif et celui-ci devient visible.
  static const Color fondClair = Color(0xFFFFFFFF);
  static const Color fondSombre = Color(0xFF1A1030);

  @override
  State<Ouverture> createState() => _OuvertureState();
}

class _OuvertureState extends State<Ouverture> {
  bool _visible = true;
  bool _termine = false;

  @override
  void initState() {
    super.initState();

    // ⚠️ Deux minuteries, et non une seule suivie d'un `setState` dans le
    //    `onEnd` du fondu : ce rappel ne se déclenche pas si l'opacité
    //    n'atteint jamais sa cible — par exemple si l'application passe en
    //    arrière-plan pendant l'animation. L'écran resterait alors bloqué sur
    //    la marque, et il faudrait tuer l'application pour en sortir.
    Future.delayed(Ouverture.tenue, () {
      if (mounted) setState(() => _visible = false);
    });
    Future.delayed(Ouverture.tenue + Ouverture.fondu, () {
      if (mounted) setState(() => _termine = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_termine) return widget.suite;

    final sombre = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // La suite est construite DESSOUS, et donc déjà prête quand la marque
        // s'efface : le fondu découvre une application chargée, pas un blanc.
        widget.suite,
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: Ouverture.fondu,
            curve: Curves.easeOut,
            child: ColoredBox(
              color: sombre ? Ouverture.fondSombre : Ouverture.fondClair,
              child: Center(
                child: Image.asset(
                  'assets/marque/symbole.png',
                  // 120 dp : la taille exacte de l'item du layer-list natif.
                  width: 120,
                  height: 120,
                  // Le symbole est déjà à sa couleur ; on ne le teinte pas.
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
