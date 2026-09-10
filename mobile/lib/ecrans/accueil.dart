import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../charte/jetons.dart';
import '../charte/theme.dart';
import '../modeles/catalogue.dart';
import '../services/services.dart';
import '../widgets/communs.dart';
import 'produit.dart';
import 'suivi.dart';

/// L'accueil.
///
/// Il répond à « qu'est-ce qui se vend ici ? » avant toute recherche — la
/// question de quelqu'un qui arrive par un lien partagé et ne connaît pas
/// GARAH.
///
/// ## ⚠️ Les tendances ne sont PAS des produits
///
/// `/produits/tendance` vient du module de mesure : elle rend un classement
/// d'identifiants, sans photo ni prix ni slug. Il faut un second appel,
/// `/produits/par-ids`, pour dessiner les vignettes — et cet appel rend les
/// produits **dans l'ordre demandé**, parce que pour un palmarès l'ordre EST
/// l'information.
///
/// ## Les blocs sont indépendants
///
/// Un catalogue neuf n'a aucune tendance, et un échec sur l'un ne doit pas
/// vider l'autre. Les lier ferait disparaître l'accueil entier pour une carte
/// manquante.
class EcranAccueil extends StatefulWidget {
  const EcranAccueil({super.key, required this.surChercher});

  /// Bascule vers l'onglet de recherche, plutôt que d'empiler un écran.
  /// Emmene au catalogue. La categorie est nulle quand on vient de la barre
  /// de recherche : on veut alors tout le catalogue, sans filtre.
  ///
  /// ⚠️ ELLE ETAIT ABSENTE. Toutes les puces appelaient le meme rappel sans
  ///    argument : on basculait sur le catalogue et la categorie etait
  ///    perdue en chemin. Cliquer sur « VETEMENTS » ne filtrait rien.
  final void Function(Categorie? categorie) surChercher;

  @override
  State<EcranAccueil> createState() => _EcranAccueilState();
}

class _EcranAccueilState extends State<EcranAccueil> {
  List<ResumeProduit> _tendances = const [];
  List<ResumeProduit> _autres = const [];
  /// L'arbre aplati : parents PUIS enfants.
  ///
  /// ⚠️ L'accueil écartait tout ce qui avait un parent — `where(parentId ==
  ///    null)` — et ne lisait jamais `enfants`. Une sous-catégorie créée au
  ///    back-office restait donc invisible aux clients.
  List<CategorieAplatie> _categories = const [];

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

    // Les tendances d'abord : le reste du catalogue a besoin de savoir
    // lesquelles retirer, et les lancer en parallèle obligerait à
    // dédoublonner deux fois.
    try {
      final classement =
          (await api.obtenir('/api/produits/tendance?limite=6')
                  as List<dynamic>)
              .map((e) => ProduitTendance.de(e as Map<String, dynamic>))
              .toList();
      _tendances = await _vignettes(
        api,
        classement.map((t) => t.produitId).toList(),
      );
    } on ErreurApi catch (e) {
      _erreur = e.message;
      _tendances = const [];
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
      _erreur = 'Une erreur inattendue est survenue. Reessayez.';
      _tendances = const [];
    }

    try {
      final page = PageDe.de(
        await api.obtenir('/api/produits?taille=12'),
        ResumeProduit.de,
      );
      final dejaVus = _tendances.map((p) => p.id).toSet();
      _autres = page.contenu.where((p) => !dejaVus.contains(p.id)).toList();
      // Le catalogue a répondu : la boutique n'est pas fermée, même si les
      // tendances ont échoué. On efface donc le message d'erreur.
      _erreur = null;
    } on ErreurApi catch (e) {
      _autres = const [];
      _erreur ??= e.message;
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
      _autres = const [];
      _erreur ??= 'Une erreur inattendue est survenue. Reessayez.';
    }

    try {
      final arbre = (await api.obtenir('/api/categories') as List<dynamic>)
          .map((e) => Categorie.de(e as Map<String, dynamic>))
          .toList();
      // ⚠️ On aplatit AVANT de couper : couper les racines à six aurait fait
      //    disparaître les sous-catégories de la septième, alors qu'elles
      //    tiennent dans la bande défilante.
      _categories = categoriesAplaties(arbre).take(12).toList();
    } on ErreurApi {
      _categories = const [];
    }

    if (mounted) setState(() => _chargement = false);
  }

  Future<List<ResumeProduit>> _vignettes(ClientApi api, List<int> ids) async {
    if (ids.isEmpty) return const [];
    final reponse = await api.obtenir(
      '/api/produits/par-ids?ids=${ids.join(',')}',
    );
    return (reponse as List<dynamic>)
        .map((e) => ResumeProduit.de(e as Map<String, dynamic>))
        .toList();
  }

  void _ouvrir(ResumeProduit p) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => EcranProduit(slug: p.slug)));
  }

  @override
  Widget build(BuildContext context) {
    final services = Services.de(context);

    return Scaffold(
      appBar: AppBar(
        // ⚠️ Le nom est COUPÉ EN DEUX, et ce n'est pas un effet : le vert est
        //    celui de la marque — la calebasse, l'onglet actif, l'écran
        //    d'ouverture — et le violet celui de l'accent du thème sombre du
        //    back-office. Les deux applications de la maison se reconnaissent
        //    à ces deux couleurs-là.
        //
        //    Les deux valeurs viennent des jetons : les écrire à la main ici
        //    ferait diverger la vitrine du reste au premier ajustement.
        titleSpacing: 16,
        title: Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'GAR',
                style: TextStyle(color: Jetons.marque),
              ),
              TextSpan(
                text: 'AH',
                // ⚠️ `accentTitre` et non `accent` : un violet presque noir
                //    sur fond clair, l'accent vif sur fond sombre. La même
                //    valeur pour les deux ferait disparaître « AH » dans l'un
                //    des deux thèmes — voir CouleursGarah.accentTitre.
                style: TextStyle(color: context.accentTitre),
              ),
            ],
          ),
          style: const TextStyle(
            // 26 au lieu de 18 : c'est le nom de la boutique, pas un titre
            // d'écran. Il n'y a rien au-dessus de lui.
            fontSize: 26,
            letterSpacing: 3,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        actions: [
          ListenableBuilder(
            listenable: services.theme,
            builder: (context, _) => IconButton(
              onPressed: services.theme.basculer,
              // Le libellé dit ce qu'on OBTIENT en appuyant, pas l'état
              // actuel : « thème sombre » sur un fond clair. L'inverse fait
              // hésiter une fois sur deux.
              tooltip: services.theme.sombre ? 'Thème clair' : 'Thème sombre',
              icon: Icon(
                services.theme.sombre
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
            ),
          ),
        ],
        toolbarHeight: 68,
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            _barreDeRecherche(context),
            _bandeauCorridor(context),
            if (_categories.isNotEmpty) _lesCategories(context),
            _bloc(
              context,
              titre: 'Ce qui se vend',
              produits: _tendances,
              // Un catalogue neuf n'a aucune tendance : elles se calculent sur
              // des ventes. Une ligne discrète, et le catalogue prend le relais
              // juste en dessous — un grand vide au milieu de l'accueil ferait
              // croire à une boutique fermée.
              siVide: 'Les articles les plus vendus apparaîtront ici.',
            ),
            _bloc(
              context,
              titre: 'Dans la boutique',
              produits: _autres,
              siVide: null,
            ),
            _lienSuivi(context),
          ],
        ),
      ),
    );
  }

  Widget _barreDeRecherche(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
    child: InkWell(
      onTap: () => widget.surChercher(null),
      borderRadius: BorderRadius.circular(Jetons.rayonPetit),
      child: IgnorePointer(
        // Un champ FACTICE : appuyer dessus bascule sur l'onglet de
        // recherche, qui a le vrai champ et les résultats. Deux champs
        // vivants sur deux écrans se désynchroniseraient.
        child: TextField(
          enabled: false,
          decoration: InputDecoration(
            hintText: 'Chercher un article…',
            prefixIcon: Icon(Icons.search, color: context.texteAttenue),
          ),
        ),
      ),
    ),
  );

  /// Ce que GARAH fait, en une phrase.
  ///
  /// Un visiteur arrivé par un lien ne sait pas qu'il faut venir retirer sa
  /// commande : le lui dire ici évite la déception au moment de payer.
  Widget _bandeauCorridor(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Jetons.marque.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(Jetons.rayonMoyen),
    ),
    child: Row(
      children: [
        const Icon(Icons.local_shipping_outlined, color: Jetons.marque),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Douala → Bangui',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                'Vous retirez votre commande au point de votre choix.',
                style: TextStyle(fontSize: 12.5, color: context.texteAttenue),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _lesCategories(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Libelle('Catégories'),
      ),
      SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _categories.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final e = _categories[i];
            final enfant = e.niveau > 0;
            return ActionChip(
              // Le chevron dit « celle-ci est dedans ». Un simple retrait ne se
              // verrait pas dans une bande qui défile horizontalement.
              label: Text(
                enfant ? '↳ ${e.categorie.nom}' : e.categorie.nom,
                style: enfant
                    ? TextStyle(fontSize: 12.5, color: context.texteAttenue)
                    : null,
              ),
              onPressed: () => widget.surChercher(e.categorie),
              shape: StadiumBorder(side: BorderSide(color: context.bordure)),
            );
          },
        ),
      ),
      const SizedBox(height: 20),
    ],
  );

  Widget _bloc(
    BuildContext context, {
    required String titre,
    required List<ResumeProduit> produits,
    required String? siVide,
  }) {
    if (_chargement) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (produits.isEmpty && siVide == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text(
            titre,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
        ),
        if (produits.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              siVide!,
              style: TextStyle(fontSize: 13, color: context.texteAttenue),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              // Plus haut que large : la photo est carrée, et il reste le nom,
              // le vendeur, le prix et parfois une étiquette.
              childAspectRatio: 0.62,
            ),
            itemCount: produits.length,
            itemBuilder: (context, i) => VignetteProduit(
              produit: produits[i],
              surAppui: () => _ouvrir(produits[i]),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// La seule page qu'on atteint sans compte.
  ///
  /// Elle mérite sa place ici : un client qui attend un colis n'ouvre pas la
  /// boutique pour acheter.
  Widget _lienSuivi(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: InkWell(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const EcranSuivi())),
      borderRadius: BorderRadius.circular(Jetons.rayonMoyen),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: context.texteAttenue.withValues(alpha: 0.35),
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(Jetons.rayonMoyen),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Suivre un colis',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sans compte, avec votre numéro de suivi.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: context.texteAttenue,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.texteAttenue),
          ],
        ),
      ),
    ),
  );
}
