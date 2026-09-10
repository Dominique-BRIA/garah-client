import 'dart:async';

import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../modeles/catalogue.dart';
import '../services/services.dart';
import '../widgets/communs.dart';
import 'produit.dart';

/// Le catalogue.
///
/// ## 🎯 La recherche part au SERVEUR
///
/// Filtrer la page reçue ne trouverait pas ce qui est en page deux, et le
/// visiteur en conclurait que l'article n'existe pas. C'est la base qui
/// cherche — sur le nom, le vendeur et la catégorie, jamais sur la référence
/// interne, qu'un client n'a jamais vue.
///
/// ## ⚠️ Deux états vides distincts
///
/// « Aucun résultat pour X » n'est pas « catalogue vide ». Proposer de changer
/// de recherche à quelqu'un qui n'a rien cherché est une réponse à côté.
///
/// ## Le chargement est incrémental
///
/// Pas de numéros de page : sur un téléphone, une barre de pagination se rate
/// une fois sur deux — et surtout, chaque page rechargée est un aller-retour
/// de plus sur une connexion qui les compte.
class EcranCatalogue extends StatefulWidget {
  const EcranCatalogue({super.key, required this.categorie});

  /// Le canal par lequel l accueil demande une categorie.
  final ValueNotifier<Categorie?> categorie;

  @override
  State<EcranCatalogue> createState() => _EcranCatalogueState();
}

class _EcranCatalogueState extends State<EcranCatalogue> {
  final _saisie = TextEditingController();
  final _defilement = ScrollController();

  /// Ce qui est APPLIQUÉ, distinct de ce qui est saisi.
  ///
  /// Les fondre ferait changer le message « aucun résultat pour… » pendant
  /// qu'on tape, alors que la liste montre encore l'ancien filtre.
  String _filtre = '';

  Timer? _attente;

  final List<ResumeProduit> _produits = [];
  int _page = 0;
  bool _derniere = false;
  bool _chargement = true;
  bool _chargementSuite = false;
  String? _erreur;

  /// La catégorie appliquée, s'il y en a une.
  ///
  /// ⚠️ On garde la CATÉGORIE et non son seul identifiant : il faut son nom
  ///    pour écrire « Vêtements » sur la puce du filtre actif. Sans ce nom, il
  ///    faudrait le rechercher dans une liste que cet écran ne charge pas.
  Categorie? _categorie;

  @override
  void initState() {
    super.initState();
    _defilement.addListener(_peutEtreLaSuite);
    _categorie = widget.categorie.value;
    widget.categorie.addListener(_surCategorieDemandee);
    _charger(remiseAZero: true);
  }

  /// L'accueil demande une catégorie.
  ///
  /// ⚠️ Cet écran est maintenu en vie d'un onglet à l'autre : c'est le seul
  ///    chemin par lequel un nouveau filtre peut l'atteindre. Un paramètre de
  ///    constructeur ne le reconstruirait pas.
  void _surCategorieDemandee() {
    final demandee = widget.categorie.value;
    if (demandee?.id == _categorie?.id) return;
    setState(() {
      _categorie = demandee;
      // La recherche tapée n'a plus de sens sous une autre catégorie : on
      // repart propre plutôt que de croiser deux filtres qu'on n'a pas
      // choisis ensemble.
      _filtre = '';
      _saisie.clear();
    });
    _charger(remiseAZero: true);
  }

  /// Retire le filtre de catégorie.
  void _retirerLaCategorie() {
    // On passe par le canal : sinon l'accueil croirait le filtre encore posé,
    // et recliquer la même catégorie ne ferait rien.
    widget.categorie.value = null;
  }

  @override
  void dispose() {
    widget.categorie.removeListener(_surCategorieDemandee);
    _attente?.cancel();
    _saisie.dispose();
    _defilement.dispose();
    super.dispose();
  }

  /// On attend une pause de frappe avant d'interroger le serveur.
  ///
  /// ⚠️ Sans ce délai, « chaussure » part en neuf requêtes. Sur une connexion
  ///    comptée, c'est neuf fois le prix d'une recherche — et les réponses
  ///    arrivent dans le désordre, si bien que la liste finit parfois sur le
  ///    résultat de « chauss ».
  void _saisi(String texte) {
    _attente?.cancel();
    _attente = Timer(const Duration(milliseconds: 400), () {
      if (texte.trim() == _filtre) return;
      _filtre = texte.trim();
      _charger(remiseAZero: true);
    });
  }

  void _peutEtreLaSuite() {
    if (_derniere || _chargementSuite || _chargement) return;
    // 400 px avant le bas : la page suivante arrive pendant qu'on fait encore
    // défiler, au lieu de s'arrêter net sur un vide.
    if (_defilement.position.pixels >=
        _defilement.position.maxScrollExtent - 400) {
      _charger(remiseAZero: false);
    }
  }

  Future<void> _charger({required bool remiseAZero}) async {
    setState(() {
      if (remiseAZero) {
        _page = 0;
        _derniere = false;
        _chargement = true;
      } else {
        _chargementSuite = true;
      }
      _erreur = null;
    });

    final parametres = <String, String>{'page': '$_page', 'taille': '24'};
    if (_filtre.isNotEmpty) parametres['recherche'] = _filtre;
    // ⚠️ Il MANQUAIT : la requete ne portait aucune categorie, si bien que
    //    cliquer sur une puce de l accueil basculait ici sans rien filtrer.
    if (_categorie != null) parametres['categorieId'] = '${_categorie!.id}';
    final requete = parametres.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    try {
      final page = PageDe.de(
        await Services.de(context).api.obtenir('/api/produits?$requete'),
        ResumeProduit.de,
      );
      if (!mounted) return;
      setState(() {
        if (remiseAZero) {
          _produits
            ..clear()
            ..addAll(page.contenu);
        } else {
          _produits.addAll(page.contenu);
        }
        _derniere = page.derniere;
        if (!page.derniere) _page++;
        _chargement = false;
        _chargementSuite = false;
      });
    } on ErreurApi catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _chargementSuite = false;
        _erreur = e.message;
      });
    } catch (_) {
      // 🎯 LE FILET, derive de la branche ci-dessus.
      //
      //    Ne rattraper que `ErreurApi` semble propre : c'est ce que leve la
      //    couche reseau. Mais tout ce qui casse APRES la reponse — un champ
      //    absent, un cast qui echoue — leve autre chose, l'exception
      //    s'echappe, et l'indicateur d'attente reste arme : l'ecran tourne
      //    indefiniment SANS message.
      //
      //    C'est exactement ce qui rendait la connexion impossible sur mobile.
      //    Le defaut etait ici aussi, dans chaque ecran, en attente.
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _chargementSuite = false;
        _erreur = 'Une erreur inattendue est survenue. Reessayez.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalogue'),
        bottom: PreferredSize(
          // ⚠️ La hauteur suit la présence de la puce. Une valeur fixe
          //    rognerait le champ de saisie dès qu'un filtre est posé.
          preferredSize: Size.fromHeight(_categorie == null ? 64 : 108),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _saisie,
                  onChanged: _saisi,
                  onSubmitted: (t) {
                    _attente?.cancel();
                    _filtre = t.trim();
                    _charger(remiseAZero: true);
                  },
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Nom, vendeur, catégorie…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _saisie.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Effacer',
                            onPressed: () {
                              _saisie.clear();
                              _filtre = '';
                              _charger(remiseAZero: true);
                            },
                          ),
                  ),
                ),
                // ⚠️ LE FILTRE DOIT SE VOIR, ET SE RETIRER.
                //
                //    Une liste filtrée sans rien qui le dise ressemble à un
                //    catalogue à moitié vide : on croit que les articles ont
                //    disparu, pas qu'on les a masqués. Et sans le moyen de
                //    l'enlever, il faut deviner qu'il faut repasser par
                //    l'accueil.
                if (_categorie != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InputChip(
                      label: Text(_categorie!.nom),
                      onDeleted: _retirerLaCategorie,
                      deleteIcon: const Icon(Icons.close, size: 18),
                      deleteButtonTooltipMessage: 'Retirer le filtre',
                      avatar: const Icon(Icons.filter_alt_outlined, size: 18),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      body: _corps(context),
    );
  }

  Widget _corps(BuildContext context) {
    if (_erreur != null && _produits.isEmpty) {
      return EtatVide(
        message: _erreur!,
        libelleAction: 'Réessayer',
        surAction: () => _charger(remiseAZero: true),
      );
    }
    if (_chargement) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_produits.isEmpty) {
      // ⚠️ LE MESSAGE DOIT NOMMER CE QUI FILTRE, sinon « le catalogue est
      //    vide » se lit comme « la boutique n'a rien » alors qu'on regarde
      //    une catégorie sans article. Et « Voir tout le catalogue » doit
      //    retirer TOUS les filtres — retirer la recherche en laissant la
      //    catégorie rendrait une liste encore vide, sur un bouton qui promet
      //    le contraire.
      if (_filtre.isEmpty && _categorie == null) {
        return const EtatVide(message: 'Le catalogue est vide pour le moment.');
      }

      final String message;
      if (_filtre.isEmpty) {
        message = 'Aucun article dans « ${_categorie!.nom} ».';
      } else if (_categorie == null) {
        message = 'Rien ne correspond à « $_filtre ».';
      } else {
        message =
            'Rien ne correspond à « $_filtre » dans « ${_categorie!.nom} ».';
      }

      return EtatVide(
        message: message,
        // On dit SUR QUOI porte la recherche : sans cette phrase, on essaie
        // une référence ou un numéro de commande, et on conclut que la
        // boutique est vide.
        detail: _filtre.isEmpty
            ? null
            : 'La recherche porte sur le nom de l’article, le vendeur et la '
                  'catégorie.',
        libelleAction: 'Voir tout le catalogue',
        surAction: () {
          _saisie.clear();
          _filtre = '';
          // Passe par le canal : sinon l'accueil croirait le filtre encore
          // posé, et recliquer la même catégorie ne ferait rien.
          if (_categorie != null) {
            widget.categorie.value = null;
          } else {
            _charger(remiseAZero: true);
          }
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () => _charger(remiseAZero: true),
      child: GridView.builder(
        controller: _defilement,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        gridDelegate: grilleProduits(context),
        itemCount: _produits.length + (_chargementSuite ? 2 : 0),
        itemBuilder: (context, i) {
          if (i >= _produits.length) {
            return const Center(child: CircularProgressIndicator());
          }
          final p = _produits[i];
          return VignetteProduit(
            produit: p,
            surAppui: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => EcranProduit(slug: p.slug)),
            ),
          );
        },
      ),
    );
  }
}
