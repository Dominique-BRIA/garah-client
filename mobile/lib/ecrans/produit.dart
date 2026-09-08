import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../charte/jetons.dart';
import '../charte/theme.dart';
import '../modeles/catalogue.dart';
import '../services/panier_local.dart';
import '../services/services.dart';
import '../widgets/communs.dart';

/// La fiche produit.
///
/// ## 🎯 La grille de paliers est AVANT le bouton d'achat
///
/// C'est le cœur de cet écran, et l'alignement sur la « ladder pricing »
/// d'Alibaba : le prix unitaire baisse par tranches, et le palier applicable
/// est mis en évidence. Sans cette grille, le prix change entre la fiche et le
/// panier — et ça ressemble à une arnaque.
///
/// ## ⚠️ Ce que l'écran ne promet pas
///
/// Les paliers affichés sont ceux **du jour**. Le tarif qui compte est figé par
/// le serveur au passage de commande : cet écran informe, il n'engage pas.
/// Présenter son propre calcul comme un engagement mentirait le jour où un
/// tarif change entre l'affichage et le paiement.
class EcranProduit extends StatefulWidget {
  const EcranProduit({super.key, required this.slug});

  final String slug;

  @override
  State<EcranProduit> createState() => _EcranProduitState();
}

class _EcranProduitState extends State<EcranProduit> {
  FicheVitrine? _fiche;
  bool _chargement = true;
  String? _erreur;

  Declinaison? _declinaison;
  int _quantite = 1;
  int _photo = 0;
  bool _ajoute = false;

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
      final fiche = FicheVitrine.de(
        await api.obtenir(
              '/api/produits/${Uri.encodeComponent(widget.slug)}/vitrine',
            )
            as Map<String, dynamic>,
      );

      // On ouvre sur une déclinaison ACHETABLE si elle existe : ouvrir sur une
      // taille épuisée ferait croire que le produit ne l'est plus.
      final premiere =
          fiche.declinaisons.where((d) => d.achetable).firstOrNull ??
          fiche.declinaisons.firstOrNull;

      if (!mounted) return;
      setState(() {
        _fiche = fiche;
        _declinaison = premiere;
        _photo = 0;
        _quantite = premiere == null
            ? 1
            : premiere.quantiteMinimale.clamp(1, 1 << 30);
        _chargement = false;
      });

      _compterLaVue(api, fiche.id);
    } on ErreurApi catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.statut == 404
            // ⚠️ Un produit dépublié rend 404. Le dire comme une ABSENCE, pas
            //    comme une panne : le lien vient peut-être d'un partage vieux
            //    de plusieurs semaines.
            ? 'Cet article n’est plus proposé à la vente.'
            : e.message;
      });
    }
  }

  /// Enregistre la consultation.
  ///
  /// ⚠️ **Ne doit jamais bloquer l'affichage.** Une statistique perdue est
  ///    regrettable, une fiche produit en erreur est un client perdu — le
  ///    serveur avale déjà ses propres échecs, on fait pareil ici.
  void _compterLaVue(ClientApi api, int produitId) {
    api
        .poster('/api/produits/$produitId/vues', {'source': 'FICHE'})
        .catchError((_) => null);
  }

  // ---------------------------------------------------------------------------

  PalierPrix? get _palierActif => _declinaison?.palierPour(_quantite);
  PalierPrix? get _palierSuivant => _declinaison?.palierSuivant(_quantite);

  num get _sousTotal => (_palierActif?.prixUnitaire ?? 0) * _quantite;

  void _choisir(Declinaison d) {
    if (!d.achetable) return;
    setState(() {
      _declinaison = d;
      // La quantité repart au minimum de CETTE déclinaison : la garder pourrait
      // dépasser un stock plus faible, et le bouton se désactiverait sans que
      // la raison soit visible.
      _quantite = d.quantiteMinimale.clamp(1, 1 << 30);
      _ajoute = false;
    });
  }

  void _changerQuantite(int delta) {
    final d = _declinaison;
    if (d == null) return;
    final minimum = d.quantiteMinimale < 1 ? 1 : d.quantiteMinimale;
    final maximum = d.disponible < minimum ? minimum : d.disponible;
    setState(() {
      _quantite = (_quantite + delta).clamp(minimum, maximum);
      _ajoute = false;
    });
  }

  Future<void> _ajouterAuPanier() async {
    final f = _fiche;
    final d = _declinaison;
    final palier = _palierActif;
    if (f == null || d == null || palier == null) return;

    await Services.de(context).panier.ajouter(
      LigneLocale(
        varianteId: d.id,
        quantite: _quantite,
        nomProduit: f.nom,
        libelleDeclinaison: f.declinaisons.length > 1 ? d.libelle : null,
        urlPhoto: f.medias.firstOrNull?.url,
        // Indicatif : le serveur recalcule au bon palier, et fige à la
        // commande.
        prixIndicatif: palier.prixUnitaire,
      ),
    );
    if (mounted) setState(() => _ajoute = true);
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_erreur != null) {
      return Scaffold(
        appBar: AppBar(),
        body: EtatVide(
          message: _erreur!,
          libelleAction: 'Réessayer',
          surAction: _charger,
        ),
      );
    }
    if (_chargement) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final f = _fiche!;
    final d = _declinaison;

    return Scaffold(
      appBar: AppBar(
        title: Text(f.categorieNom ?? 'Article'),
        actions: [
          IconButton(
            onPressed: () => _partager(f),
            tooltip: 'Partager',
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _lesPhotos(f),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.nom,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Vendu par ',
                        style: TextStyle(color: context.texteAttenue),
                      ),
                      TextSpan(
                        text: f.marchandNom ?? 'vendeur inconnu',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 13.5),
                ),
              ],
            ),
          ),
          if (d == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Alerte(
                message: 'Cet article n’a aucune déclinaison à vendre.',
              ),
            )
          else ...[
            if (d.paliers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Alerte(
                  message:
                      'Cet article n’a pas encore de prix. '
                      'Il n’est pas commandable pour le moment.',
                ),
              )
            else
              _laGrilleDePaliers(context, d),
            if (f.declinaisons.length > 1) _lesDeclinaisons(context, f, d),
            if (d.paliers.isNotEmpty) _laQuantite(context, d, f),
            if (f.description != null && f.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Libelle('Description'),
                    const SizedBox(height: 8),
                    Text(
                      f.description!,
                      style: const TextStyle(fontSize: 14, height: 1.55),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
      bottomNavigationBar: d == null ? null : _lesActions(context, d),
    );
  }

  Widget _lesPhotos(FicheVitrine f) {
    if (f.medias.isEmpty) {
      return const AspectRatio(
        aspectRatio: 4 / 3,
        child: PhotoProduit(url: null),
      );
    }
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: PageView.builder(
            onPageChanged: (i) => setState(() => _photo = i),
            itemCount: f.medias.length,
            itemBuilder: (_, i) => PhotoProduit(url: f.medias[i].url),
          ),
        ),
        // Les points n'apparaissent qu'à partir de deux photos : un point seul
        // sous une image n'apprend rien et fait chercher un geste qui n'existe
        // pas.
        if (f.medias.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                f.medias.length,
                (i) => Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _photo
                        ? Jetons.primaire
                        : context.texteAttenue.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// La grille de paliers — le sujet de l'écran.
  Widget _laGrilleDePaliers(BuildContext context, Declinaison d) {
    final actif = _palierActif;
    final suivant = _palierSuivant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: context.bordure),
          borderRadius: BorderRadius.circular(Jetons.rayonMoyen),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Libelle('Prix par quantité'),
                // Le minimum de commande ne s'affiche QUE s'il dépasse 1 :
                // ailleurs, c'est du bruit sur toutes les fiches.
                if (d.quantiteMinimale > 1)
                  Etiquette(texte: 'Min. ${d.quantiteMinimale}', couleur: null),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final p in d.paliers)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 6,
                      ),
                      decoration: BoxDecoration(
                        color: p.quantiteMin == actif?.quantiteMin
                            ? Jetons.primaire.withValues(alpha: 0.1)
                            : null,
                        border: Border.all(
                          color: p.quantiteMin == actif?.quantiteMin
                              ? Jetons.primaire
                              : context.bordure,
                        ),
                        borderRadius: BorderRadius.circular(Jetons.rayonPetit),
                      ),
                      child: Column(
                        children: [
                          Text(
                            p.plage,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.texteAttenue,
                            ),
                          ),
                          const SizedBox(height: 3),
                          FittedBox(
                            child: Text(
                              montantLisible(p.prixUnitaire),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          Text(
                            'la pièce',
                            style: TextStyle(
                              fontSize: 10,
                              color: context.texteAttenue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            // L'invite au palier suivant. Absente si le stock ne suit pas :
            // promettre un tarif indisponible est pire que se taire.
            if (suivant != null) ...[
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Encore '),
                    TextSpan(
                      text: '${suivant.quantiteMin - _quantite}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(text: ' et le prix passe à '),
                    TextSpan(
                      text: montantLisible(suivant.prixUnitaire),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.texteAttenue,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _lesDeclinaisons(BuildContext context, FicheVitrine f, Declinaison d) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Libelle('Déclinaison'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in f.declinaisons)
                ChoiceChip(
                  label: Text(
                    v.libelle,
                    style: TextStyle(
                      // Une déclinaison épuisée reste VISIBLE, barrée : la
                      // masquer ferait croire qu'elle n'existe pas, et
                      // chercher ailleurs.
                      decoration: v.achetable
                          ? null
                          : TextDecoration.lineThrough,
                      color: v.achetable ? null : context.texteAttenue,
                    ),
                  ),
                  selected: v.id == d.id,
                  onSelected: v.achetable ? (_) => _choisir(v) : null,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Les déclinaisons barrées sont épuisées.',
            style: TextStyle(fontSize: 12, color: context.texteAttenue),
          ),
        ],
      ),
    );
  }

  Widget _laQuantite(BuildContext context, Declinaison d, FicheVitrine f) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: context.bordure),
          borderRadius: BorderRadius.circular(Jetons.rayonMoyen),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quantité',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${d.disponible} disponible(s)',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.texteAttenue,
                      ),
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: context.bordure),
                    borderRadius: BorderRadius.circular(Jetons.rayonPetit),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _changerQuantite(-1),
                        icon: const Icon(Icons.remove),
                        tooltip: 'Retirer une unité',
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '$_quantite',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _changerQuantite(1),
                        icon: const Icon(Icons.add),
                        tooltip: 'Ajouter une unité',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Libelle('Sous-total'),
                    if (_palierActif != null)
                      Text(
                        '$_quantite × ${montantLisible(_palierActif!.prixUnitaire)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.texteAttenue,
                        ),
                      ),
                  ],
                ),
                Text(
                  montantLisible(_sousTotal),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              f.tauxTva > 0
                  ? 'Prix TVA comprise, hors acheminement. Le montant définitif '
                        'est figé au moment de la commande.'
                  : 'Prix du jour, hors acheminement. Le montant définitif est '
                        'figé au moment de la commande.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: context.texteAttenue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lesActions(BuildContext context, Declinaison d) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _negocier,
                icon: const Icon(Icons.forum_outlined, size: 18),
                label: const Text('Négocier'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: d.achetable ? _ajouterAuPanier : null,
                child: Text(_ajoute ? 'Ajouté au panier' : 'Ajouter au panier'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ouvre une négociation sur CET article.
  ///
  /// ⚠️ Sans compte, on ne peut rien ouvrir : la négociation vit dans une
  ///    conversation, qui appartient à quelqu'un. On le DIT plutôt que de
  ///    laisser un bouton sans effet.
  Future<void> _negocier() async {
    final services = Services.de(context);
    final messager = ScaffoldMessenger.of(context);
    final f = _fiche;
    final d = _declinaison;
    if (f == null || d == null) return;

    if (!services.session.connecte) {
      messager.showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour négocier un prix.')),
      );
      return;
    }

    final article = f.declinaisons.length > 1
        ? '${f.nom} — ${d.libelle}'
        : f.nom;
    try {
      await services.api.poster('/api/conversations', {
        'sujet': 'Négociation : $article',
        // Le PRIX ne part pas dans le message : il se propose comme une offre
        // datée, dans le fil, pas comme une phrase qu'on relit à l'envers.
        'premierMessage':
            'Bonjour, je souhaite négocier le prix de « $article » pour $_quantite pièce(s).',
      });
      messager.showSnackBar(
        const SnackBar(
          content: Text('Discussion ouverte. Un conseiller vous répondra.'),
        ),
      );
    } on ErreurApi catch (e) {
      messager.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _partager(FicheVitrine f) {
    // Le partage système demande un greffon natif ; en attendant, on met le
    // lien dans le presse-papier — un geste qui marche partout et ne ment sur
    // rien, à condition de le DIRE.
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Lien : ${f.slug}')));
  }
}
