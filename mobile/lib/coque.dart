import 'package:flutter/material.dart';

import 'ecrans/accueil.dart';
import 'ecrans/catalogue.dart';
import 'ecrans/compte.dart';
import 'ecrans/panier.dart';
import 'services/services.dart';

/// La coque : quatre destinations, une barre en bas.
///
/// ## Pourquoi une barre EN BAS, et non un tiroir
///
/// Le pouce y arrive sans changer la prise du téléphone. Un tiroir latéral
/// cache ses entrées derrière un geste qu'il faut deviner — et sur un premier
/// usage, ce qui n'est pas visible n'existe pas.
///
/// ## ⚠️ `IndexedStack`, et non un remplacement d'écran
///
/// Les quatre onglets restent **montés**. Sans cela, revenir au catalogue
/// après un détour par le panier rechargerait la liste et perdrait la position
/// de défilement : on se retrouve en haut d'une page qu'on avait parcourue,
/// et sur une connexion comptée, on repaie la requête.
class Coque extends StatefulWidget {
  const Coque({super.key});

  @override
  State<Coque> createState() => _CoqueState();
}

class _CoqueState extends State<Coque> {
  int _onglet = 0;

  @override
  Widget build(BuildContext context) {
    final services = Services.de(context);

    return Scaffold(
      body: IndexedStack(
        index: _onglet,
        children: [
          EcranAccueil(surChercher: () => setState(() => _onglet = 1)),
          const EcranCatalogue(),
          const EcranPanier(),
          const EcranCompte(),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        // La pastille du panier suit le panier local : sans cette écoute, on
        // ajoute un article et le compteur ne bouge pas — on ajoute alors une
        // seconde fois.
        listenable: services.panier,
        builder: (context, _) => NavigationBar(
          selectedIndex: _onglet,
          onDestinationSelected: (i) => setState(() => _onglet = i),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Accueil',
            ),
            const NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search),
              label: 'Chercher',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: services.panier.nombreArticles > 0,
                label: Text('${services.panier.nombreArticles}'),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: services.panier.nombreArticles > 0,
                label: Text('${services.panier.nombreArticles}'),
                child: const Icon(Icons.shopping_cart),
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
}
