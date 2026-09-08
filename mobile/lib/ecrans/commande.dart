import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../charte/jetons.dart';
import '../charte/theme.dart';
import '../modeles/catalogue.dart';
import '../services/services.dart';
import '../widgets/communs.dart';
import 'paiement.dart';

/// Un point de récupération, tel que la route publique le rend.
class PointRecuperation {
  const PointRecuperation({
    required this.id,
    required this.nom,
    required this.ville,
    required this.adresse,
    required this.horaires,
    required this.fraisAcheminement,
  });

  final int id;
  final String nom;
  final String ville;
  final String? adresse;
  final String? horaires;
  final num fraisAcheminement;

  factory PointRecuperation.de(Map<String, dynamic> j) => PointRecuperation(
    id: (j['id'] as num).toInt(),
    nom: (j['nom'] as String?) ?? '',
    ville: (j['ville'] as String?) ?? '',
    adresse: j['adresse'] as String?,
    horaires: j['horaires'] as String?,
    fraisAcheminement: (j['fraisAcheminement'] as num?) ?? 0,
  );
}

class _LignePanier {
  const _LignePanier({
    required this.designation,
    required this.quantite,
    required this.montantLigne,
    required this.vendable,
  });

  final String designation;
  final int quantite;
  final num montantLigne;

  /// Faux si le stock a bougé depuis l'ajout. Le serveur le dit ; l'écran doit
  /// le montrer AVANT le clic, pas après le refus.
  final bool vendable;

  factory _LignePanier.de(Map<String, dynamic> j) => _LignePanier(
    designation: (j['designation'] as String?) ?? 'Article',
    quantite: (j['quantite'] as num?)?.toInt() ?? 0,
    montantLigne: (j['montantLigne'] as num?) ?? 0,
    vendable: (j['vendable'] as bool?) ?? true,
  );
}

class _ContenuPanier {
  const _ContenuPanier({
    required this.lignes,
    required this.montantArticles,
    required this.indisponibles,
  });

  final List<_LignePanier> lignes;
  final num montantArticles;
  final List<String> indisponibles;

  factory _ContenuPanier.de(Map<String, dynamic> j) => _ContenuPanier(
    lignes: (j['lignes'] as List<dynamic>? ?? [])
        .map((e) => _LignePanier.de(e as Map<String, dynamic>))
        .toList(),
    montantArticles: (j['montantArticles'] as num?) ?? 0,
    indisponibles: (j['indisponibles'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList(),
  );
}

/// Passer commande.
///
/// ## 🎯 UN SEUL ÉCRAN, pas un tunnel
///
/// Il n'y a ni adresse, ni transporteur, ni créneau à choisir : GARAH ne livre
/// pas à domicile. Le seul choix réel est le **lieu de retrait**. Un tunnel en
/// quatre étapes ferait abandonner pour rien.
///
/// ## ⚠️ Le total n'existe qu'une fois le point choisi
///
/// Les frais d'acheminement dépendent du point. Afficher un total avant ce
/// choix serait un chiffre qui change sous les yeux — et un chiffre qui change
/// après qu'on a décidé d'acheter, c'est un achat qu'on ne fait pas.
///
/// ## ⚠️ Le panier vient du SERVEUR, pas du téléphone
///
/// Le panier local sert à ne pas perdre ce qu'on a choisi ; il n'est jamais la
/// vérité. Le stock et le prix se décident côté serveur, et c'est son panier à
/// lui qu'on paie.
class EcranCommande extends StatefulWidget {
  const EcranCommande({super.key});

  @override
  State<EcranCommande> createState() => _EcranCommandeState();
}

class _EcranCommandeState extends State<EcranCommande> {
  List<PointRecuperation> _points = const [];
  _ContenuPanier? _panier;
  int? _pointId;

  bool _chargement = true;
  bool _envoi = false;
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
      final points =
          (await api.obtenir('/api/lieux/points-recuperation') as List<dynamic>)
              .map((e) => PointRecuperation.de(e as Map<String, dynamic>))
              .toList();
      final panier = _ContenuPanier.de(
        await api.obtenir('/api/panier') as Map<String, dynamic>,
      );

      if (!mounted) return;
      setState(() {
        _points = points;
        _panier = panier;
        _chargement = false;
        // ⚠️ AUCUN point pré-choisi. C'est le seul choix de l'écran, et il
        //    décide où l'on ira physiquement chercher sa marchandise : le
        //    pré-remplir ferait valider sans lire, et découvrir la ville au
        //    moment du retrait.
        _pointId = null;
      });
    } on ErreurApi catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.message;
      });
    }
  }

  PointRecuperation? get _point =>
      _points.where((p) => p.id == _pointId).firstOrNull;

  num get _frais => _point?.fraisAcheminement ?? 0;
  num get _total => (_panier?.montantArticles ?? 0) + _frais;

  Future<void> _valider() async {
    if (_pointId == null || _envoi) return;
    setState(() {
      _envoi = true;
      _erreur = null;
    });

    final api = Services.de(context).api;
    final navigateur = Navigator.of(context);
    try {
      final commande =
          await api.poster('/api/commandes', {
                'pointRecuperationId': _pointId,
                'langue': 'fr',
              })
              as Map<String, dynamic>;

      if (!mounted) return;
      setState(() => _envoi = false);
      // On REMPLACE l'écran : revenir en arrière sur un panier déjà commandé
      // ferait passer une seconde commande sans s'en rendre compte.
      navigateur.pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              EcranPaiement(commandeId: (commande['id'] as num).toInt()),
        ),
      );
    } on ErreurApi catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        // Le serveur sait pourquoi il refuse — stock parti, panier vide. Son
        // message est plus juste que celui qu'on inventerait.
        _erreur = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passer commande')),
      body: _corps(context),
      bottomNavigationBar: _chargement || _panier == null
          ? null
          : _leTotal(context),
    );
  }

  Widget _corps(BuildContext context) {
    if (_chargement) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_panier == null) {
      return EtatVide(
        message: _erreur ?? 'Votre panier n’a pas pu être chargé.',
        libelleAction: 'Réessayer',
        surAction: _charger,
      );
    }
    if (_panier!.lignes.isEmpty) {
      return const EtatVide(
        message: 'Votre panier est vide.',
        detail: 'Ajoutez des articles avant de commander.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ⚠️ Ce qui a disparu du stock se dit EN HAUT, avant même le choix du
        //    point. Le découvrir au moment de valider, c'est refaire tout
        //    l'écran pour rien.
        if (_panier!.indisponibles.isNotEmpty) ...[
          Alerte(
            message:
                'Ces articles ne sont plus disponibles et ne seront pas '
                'commandés :\n${_panier!.indisponibles.join('\n')}',
          ),
          const SizedBox(height: 18),
        ],

        const Libelle('Où retirer votre commande'),
        const SizedBox(height: 4),
        Text(
          'GARAH ne livre pas à domicile : vous venez chercher votre '
          'marchandise au point de votre choix.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.45,
            color: context.texteAttenue,
          ),
        ),
        const SizedBox(height: 12),
        for (final p in _points) _unPoint(context, p),

        const SizedBox(height: 22),
        const Libelle('Votre commande'),
        const SizedBox(height: 10),
        for (final l in _panier!.lignes) _uneLigne(context, l),

        if (_erreur != null) ...[
          const SizedBox(height: 16),
          Alerte(message: _erreur!),
        ],
      ],
    );
  }

  Widget _unPoint(BuildContext context, PointRecuperation p) {
    final choisi = p.id == _pointId;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: choisi ? Jetons.primaire.withValues(alpha: 0.07) : null,
        border: Border.all(color: choisi ? Jetons.primaire : context.bordure),
        borderRadius: BorderRadius.circular(Jetons.rayonMoyen),
      ),
      child: InkWell(
        onTap: () => setState(() => _pointId = p.id),
        borderRadius: BorderRadius.circular(Jetons.rayonMoyen),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                choisi
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: choisi ? Jetons.primaire : context.texteAttenue,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nom,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      p.ville,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.texteAttenue,
                      ),
                    ),
                    if (p.adresse != null && p.adresse!.isNotEmpty)
                      Text(
                        p.adresse!,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.texteAttenue,
                        ),
                      ),
                    if (p.horaires != null && p.horaires!.isNotEmpty)
                      Text(
                        p.horaires!,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.texteAttenue,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // 🎯 LES FRAIS SONT SUR LA LIGNE DU POINT, pas dans un
              //    récapitulatif plus bas. Ils font partie du choix : c'est
              //    souvent ce qui départage deux points d'une même ville.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    montantLisible(p.fraisAcheminement),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    'acheminement',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: context.texteAttenue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _uneLigne(BuildContext context, _LignePanier l) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.designation,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  decoration: l.vendable ? null : TextDecoration.lineThrough,
                  color: l.vendable ? null : context.texteAttenue,
                ),
              ),
              Text(
                '${l.quantite} article(s)',
                style: TextStyle(fontSize: 12, color: context.texteAttenue),
              ),
            ],
          ),
        ),
        Text(
          montantLisible(l.montantLigne),
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );

  Widget _leTotal(BuildContext context) {
    final choisi = _pointId != null;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: context.bordure)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ligneTotal(context, 'Articles', _panier!.montantArticles),
            const SizedBox(height: 4),
            _ligneTotal(
              context,
              'Frais d’acheminement',
              choisi ? _frais : null,
              // Tant qu'aucun point n'est choisi, les frais sont INCONNUS et
              // non nuls. Écrire « 0 FCFA » promettrait la gratuité.
              siInconnu: 'selon le point',
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total à payer',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                Text(
                  choisi ? montantLisible(_total) : '—',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 🎯 Dire ce qui manque AVANT le clic. Un bouton grisé sans raison
            //    fait chercher la panne ailleurs.
            if (!choisi)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choisissez le point où vous viendrez retirer votre commande.',
                  style: const TextStyle(fontSize: 12.5, color: Jetons.alerte),
                ),
              ),
            if (!choisi) const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: choisi && !_envoi && _panier!.lignes.isNotEmpty
                    ? _valider
                    : null,
                child: Text(_envoi ? 'Enregistrement…' : 'Commander et payer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ligneTotal(
    BuildContext context,
    String libelle,
    num? valeur, {
    String? siInconnu,
  }) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        libelle,
        style: TextStyle(fontSize: 13, color: context.texteAttenue),
      ),
      Text(
        valeur != null ? montantLisible(valeur) : (siInconnu ?? '—'),
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: valeur == null ? context.texteAttenue : null,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );
}
