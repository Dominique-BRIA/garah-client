import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../charte/theme.dart';
import '../modeles/catalogue.dart';
import '../services/services.dart';
import '../widgets/communs.dart';
import 'produit.dart';

/// Ma liste d'envies.
///
/// ## Deux appels, jamais un par ligne
///
/// Le serveur tient des **identifiants** — le module de mesure ne connaît pas
/// le catalogue, et ne doit pas le connaître. Les vignettes viennent d'un
/// second appel, `/produits/par-ids`, qui les rend toutes d'un coup et **dans
/// l'ordre demandé**.
///
/// ## ⚠️ On peut recevoir moins d'articles qu'on n'en a mis
///
/// Un produit dépublié depuis disparaît de la réponse. C'est voulu : le garder
/// afficherait un article qu'on ne peut plus acheter. L'écran le **dit**
/// plutôt que de laisser croire à une liste tronquée par accident.
class EcranFavoris extends StatefulWidget {
  const EcranFavoris({super.key});

  @override
  State<EcranFavoris> createState() => _EcranFavorisState();
}

class _EcranFavorisState extends State<EcranFavoris> {
  List<ResumeProduit> _produits = const [];
  int _disparus = 0;
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });

    final api = Services.de(context).api;
    try {
      final ids = (await api.obtenir('/api/favoris/miens') as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList();

      if (ids.isEmpty) {
        if (!mounted) return;
        setState(() {
          _produits = const [];
          _disparus = 0;
          _chargement = false;
        });
        return;
      }

      final produits =
          (await api.obtenir('/api/produits/par-ids?ids=${ids.join(',')}')
                  as List<dynamic>)
              .map((e) => ResumeProduit.de(e as Map<String, dynamic>))
              .toList();

      if (!mounted) return;
      setState(() {
        _produits = produits;
        _disparus = ids.length - produits.length;
        _chargement = false;
      });
    } on ErreurApi catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ma liste')),
      body: _corps(context),
    );
  }

  Widget _corps(BuildContext context) {
    if (_chargement) return const Center(child: CircularProgressIndicator());
    if (_erreur != null) {
      return EtatVide(
        message: _erreur!,
        libelleAction: 'Réessayer',
        surAction: _charger,
      );
    }
    if (_produits.isEmpty) {
      return const EtatVide(
        message: 'Votre liste est vide.',
        detail:
            'Le cœur sur un article l’ajoute ici, et vous le retrouvez '
            'd’un appareil à l’autre.',
      );
    }

    return RefreshIndicator(
      onRefresh: _charger,
      child: CustomScrollView(
        slivers: [
          if (_disparus > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  '$_disparus article(s) de votre liste ne sont plus proposés '
                  'à la vente.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: context.texteAttenue,
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.62,
              ),
              delegate: SliverChildBuilderDelegate((context, i) {
                final p = _produits[i];
                return VignetteProduit(
                  produit: p,
                  surAppui: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EcranProduit(slug: p.slug),
                      ),
                    );
                    // On peut avoir retiré l'article de sa liste depuis la
                    // fiche : recharger au retour évite d'afficher un cœur
                    // rempli sur un article qu'on vient d'enlever.
                    if (mounted) _charger();
                  },
                );
              }, childCount: _produits.length),
            ),
          ),
        ],
      ),
    );
  }
}
