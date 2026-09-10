import 'package:flutter/material.dart';

import 'charte/jetons.dart';
import 'ecrans/accueil.dart';
import 'ecrans/catalogue.dart';
import 'ecrans/compte.dart';
import 'ecrans/panier.dart';
import 'ecrans/sav.dart';
import 'services/services.dart';

/// La coque : quatre destinations, une barre en bas.
///
/// ## Pourquoi une barre EN BAS, et non un tiroir
///
/// Le pouce y arrive sans changer la prise du téléphone. Un tiroir latéral
/// cache ses entrées derrière un geste qu'il faut deviner — et sur un premier
/// usage, ce qui n'est pas visible n'existe pas.
///
/// ## Le glissement du doigt change d'onglet
///
/// Un `PageView` plutôt qu'un `IndexedStack` : sur un téléphone, glisser est le
/// geste le moins cher — il ne demande pas de viser. La barre reste là pour
/// sauter d'un bout à l'autre.
///
/// ⚠️ `keepAlive` sur chaque page, sinon on perd tout ce que le `PageView`
///    laisse sortir de l'écran. Revenir aux discussions après un détour par
///    le panier rechargerait la liste et perdrait la position de défilement : on
///    se retrouve en haut d'une page qu'on avait parcourue, et sur une
///    connexion comptée, on repaie la requête.
class Coque extends StatefulWidget {
  const Coque({super.key});

  @override
  State<Coque> createState() => _CoqueState();
}

class _CoqueState extends State<Coque> {
  final _pages = PageController();
  int _onglet = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Aller à un onglet depuis la barre.
  ///
  /// ⚠️ `jumpToPage` et non `animateToPage` quand le saut dépasse un onglet :
  ///    une animation qui traverse deux écrans les construit tous les deux au
  ///    passage, et l'un d'eux lance ses requêtes pour rien.
  void _allerA(int i) {
    if ((i - _onglet).abs() > 1) {
      _pages.jumpToPage(i);
    } else {
      _pages.animateToPage(
        i,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = Services.de(context);

    return Scaffold(
      body: PageView(
        controller: _pages,
        onPageChanged: (i) => setState(() => _onglet = i),
        children: [
          _Vivante(
            child: EcranAccueil(
              // ⚠️ Le catalogue n'est plus un onglet, mais l'écran existe
              //    toujours : la recherche et les puces de catégorie l'OUVRENT
              //    par-dessus l'accueil, avec une flèche de retour. On revient
              //    ainsi là d'où l'on venait, au lieu d'atterrir sur un onglet
              //    qu'on n'avait pas choisi.
              surChercher: (categorie) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EcranCatalogue(categorie: categorie),
                  ),
                );
              },
            ),
          ),
          const _Vivante(child: EcranDiscussions()),
          const _Vivante(child: EcranPanier()),
          const _Vivante(child: EcranCompte()),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        // La pastille du panier suit le panier local : sans cette écoute, on
        // ajoute un article et le compteur ne bouge pas — on ajoute alors une
        // seconde fois.
        listenable: services.panier,
        builder: (context, _) => NavigationBar(
          selectedIndex: _onglet,
          onDestinationSelected: _allerA,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Accueil',
            ),
            // ⚠️ « Discussions » et non « Mes discussions » : quatre cases sur
            //    un écran de 360 points, et quinze caractères passeraient sur
            //    deux lignes. Le web emploie le même mot dans sa barre du bas.
            const NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum),
              label: 'Discussions',
            ),
            NavigationDestination(
              icon: _pastille(
                services,
                const Icon(Icons.shopping_cart_outlined),
              ),
              selectedIcon: _pastille(
                services,
                const Icon(Icons.shopping_cart),
              ),
              label: 'Panier',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Compte',
            ),
          ],
        ),
      ),
    );
  }

  Widget _pastille(Services services, Widget icone) => Badge(
    isLabelVisible: services.panier.nombreArticles > 0,
    label: Text('${services.panier.nombreArticles}'),
    backgroundColor: Jetons.accentSecondaire,
    child: icone,
  );
}

/// Garde une page montée quand le `PageView` la fait sortir de l'écran.
///
/// Sans elle, chaque glissement détruit l'écran qu'on quitte : on revient sur
/// une liste rechargée depuis le début, et la requête est repayée.
class _Vivante extends StatefulWidget {
  const _Vivante({required this.child});

  final Widget child;

  @override
  State<_Vivante> createState() => _VivanteState();
}

class _VivanteState extends State<_Vivante> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
