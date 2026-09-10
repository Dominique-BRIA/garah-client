import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../charte/jetons.dart';
import '../charte/theme.dart';
import '../modeles/catalogue.dart';
import '../services/services.dart';
import '../widgets/communs.dart';
import 'commande.dart' show PointRecuperation;
import 'paiement.dart';
import 'suivi.dart';

class _LigneCommande {
  const _LigneCommande({
    required this.id,
    required this.designation,
    required this.quantite,
    required this.prixUnitaire,
    required this.montantLigne,
  });

  /// L'identifiant de la LIGNE, distinct de celui de la variante : c'est lui
  /// qu'un retour désigne, parce que c'est la ligne qui porte le prix figé.
  final int id;
  final String designation;
  final int quantite;
  final num prixUnitaire;
  final num montantLigne;

  factory _LigneCommande.de(Map<String, dynamic> j) => _LigneCommande(
    id: (j['id'] as num?)?.toInt() ?? 0,
    designation: (j['designation'] as String?) ?? 'Article',
    quantite: (j['quantite'] as num?)?.toInt() ?? 0,
    prixUnitaire: (j['prixUnitaire'] as num?) ?? 0,
    montantLigne: (j['montantLigne'] as num?) ?? 0,
  );
}

class _Commande {
  const _Commande({
    required this.id,
    required this.numero,
    required this.statut,
    required this.pointRecuperationId,
    required this.montantArticles,
    required this.montantFrais,
    required this.montantRemise,
    required this.montantTotal,
    required this.devise,
    required this.dateCreation,
    required this.lignes,
  });

  final int id;
  final String numero;
  final String statut;
  final int? pointRecuperationId;
  final num montantArticles;
  final num montantFrais;
  final num montantRemise;
  final num montantTotal;
  final String devise;
  final DateTime? dateCreation;
  final List<_LigneCommande> lignes;

  factory _Commande.de(Map<String, dynamic> j) => _Commande(
    id: (j['id'] as num).toInt(),
    numero: (j['numero'] as String?) ?? '',
    statut: (j['statut'] as String?) ?? '',
    pointRecuperationId: (j['pointRecuperationId'] as num?)?.toInt(),
    montantArticles: (j['montantArticles'] as num?) ?? 0,
    montantFrais: (j['montantFrais'] as num?) ?? 0,
    montantRemise: (j['montantRemise'] as num?) ?? 0,
    montantTotal: (j['montantTotal'] as num?) ?? 0,
    devise: (j['devise'] as String?) ?? 'XAF',
    dateCreation: DateTime.tryParse((j['dateCreation'] as String?) ?? ''),
    lignes: (j['lignes'] as List<dynamic>? ?? [])
        .map((e) => _LigneCommande.de(e as Map<String, dynamic>))
        .toList(),
  );
}

/// Ce que le serveur rend de MON retrait. Le code y est nul **deux** fois.
class _MonRetrait {
  const _MonRetrait({
    required this.numeroExpedition,
    required this.numerosSuivi,
    required this.codeRetrait,
    required this.statut,
    required this.dateRetrait,
  });

  final String numeroExpedition;

  /// Les numeros de suivi des colis de cet envoi.
  ///
  /// C'est le numero que le guichet public « Suivre un colis » sait lire. Il
  /// n'etait donne NULLE PART au client : la boutique proposait un suivi que
  /// ses propres clients ne pouvaient pas utiliser pour leur commande.
  ///
  /// Un envoi peut porter plusieurs colis — d'ou une liste.
  final List<String> numerosSuivi;

  final String? codeRetrait;

  /// Nul tant qu'AUCUN retrait n'est prepare — l'envoi est alors en route.
  /// A distinguer de 'EN_ATTENTE', qui veut dire « arrive, a retirer ».
  final String? statut;

  final DateTime? dateRetrait;

  factory _MonRetrait.de(Map<String, dynamic> j) => _MonRetrait(
    numeroExpedition: (j['numeroExpedition'] as String?) ?? '',
    numerosSuivi: ((j['numerosSuivi'] as List<dynamic>?) ?? const [])
        .whereType<String>()
        .toList(),
    codeRetrait: j['codeRetrait'] as String?,
    statut: j['statut'] as String?,
    dateRetrait: DateTime.tryParse((j['dateRetrait'] as String?) ?? ''),
  );

  bool get remis => statut == 'CONFIRME';
}

/// Le détail d'une commande — et le code qui permet d'en repartir.
///
/// ## 🎯 Le code de retrait ne vit QUE sur cet écran
///
/// Il n'est ni dans la liste des commandes, ni dans une URL. C'est un **secret
/// partagé** : le présenter au comptoir suffit à emporter la marchandise. Dans
/// une liste, il apparaîtrait sur la capture d'écran qu'on envoie à un proche
/// pour lui montrer ses achats.
///
/// ## ⚠️ Un code absent ne veut pas dire « pas encore prêt »
///
/// Le serveur le tait dans **deux** situations : avant l'arrivée de la
/// marchandise, et après la remise. C'est le statut qui les distingue —
/// l'écran ne doit jamais déduire l'une de l'autre, sous peine de dire « en
/// route » à quelqu'un qui a déjà tout emporté.
///
/// ## Les montants viennent de la commande, jamais du catalogue
///
/// C'est ce qui rend une facture de mars encore juste en septembre.
class EcranDetailCommande extends StatefulWidget {
  const EcranDetailCommande({super.key, required this.commandeId});

  final int commandeId;

  @override
  State<EcranDetailCommande> createState() => _EcranDetailCommandeState();
}

class _EcranDetailCommandeState extends State<EcranDetailCommande> {
  _Commande? _commande;
  List<_MonRetrait> _retraits = const [];
  List<PointRecuperation> _points = const [];

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
      final c = _Commande.de(
        await api.obtenir('/api/commandes/miennes/${widget.commandeId}')
            as Map<String, dynamic>,
      );
      if (!mounted) return;
      setState(() {
        _commande = c;
        _chargement = false;
      });
    } on ErreurApi catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        // ⚠️ Le serveur répond « introuvable » AUSSI pour la commande d'un
        //    autre : un 403 confirmerait qu'elle existe. On reprend le mot tel
        //    quel, sans deviner laquelle des deux situations c'est — nous ne
        //    le savons pas non plus.
        _erreur = e.statut == 404
            ? 'Cette commande est introuvable.'
            : e.message;
      });
      return;
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
        // ⚠️ Le serveur répond « introuvable » AUSSI pour la commande d'un
        //    autre : un 403 confirmerait qu'elle existe. On reprend le mot tel
        //    quel, sans deviner laquelle des deux situations c'est — nous ne
        //    le savons pas non plus.
        _erreur = 'Une erreur inattendue est survenue. Reessayez.';
      });
      return;
    }

    // ⚠️ Deux appels à part, dont l'échec ne masque JAMAIS la commande.
    //    Montants, articles et point de retrait restent utiles sans eux ;
    //    l'inverse ferait disparaître une facture pour un code qui n'existe
    //    peut-être pas encore.
    try {
      _retraits =
          (await api.obtenir(
                    '/api/expeditions/commandes/${widget.commandeId}/mon-retrait',
                  )
                  as List<dynamic>)
              .map((e) => _MonRetrait.de(e as Map<String, dynamic>))
              .toList();
    } on ErreurApi {
      _retraits = const [];
    }

    try {
      _points =
          (await api.obtenir('/api/lieux/points-recuperation') as List<dynamic>)
              .map((e) => PointRecuperation.de(e as Map<String, dynamic>))
              .toList();
    } on ErreurApi {
      _points = const [];
    }

    if (mounted) setState(() {});
  }

  /// Le point de récupération, NOMMÉ.
  ///
  /// La commande n'en porte que l'identifiant. « Point 12 » n'a jamais conduit
  /// personne quelque part — c'est le défaut corrigé sur le suivi public, et
  /// il n'a pas à revenir ici.
  PointRecuperation? get _point {
    final id = _commande?.pointRecuperationId;
    return id == null ? null : _points.where((p) => p.id == id).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    if (_erreur != null && _commande == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EtatVide(message: _erreur!),
      );
    }
    if (_chargement) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final c = _commande!;
    final etat = statutsCommande[c.statut];

    return Scaffold(
      appBar: AppBar(title: Text(c.numero)),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (c.dateCreation != null)
                  Text(
                    'Commandé le ${_jour(c.dateCreation!)}',
                    style: TextStyle(fontSize: 13, color: context.texteAttenue),
                  ),
                Etiquette(
                  texte: etat?.texte ?? c.statut,
                  couleur: etat?.couleur,
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ================================================================
            // LE CODE DE RETRAIT — en tête, et rien avant
            // ================================================================
            // C'est la seule raison d'ouvrir cet écran quand la marchandise est
            // arrivée. Le mettre après la liste des articles obligerait à faire
            // défiler devant l'agent du comptoir.
            for (final r in _retraits) ...[
              // ============================================================
              // LE SUIVI — des le depart, pas a l'arrivee
              // ============================================================
              // « Ou est mon colis » se demande PENDANT le trajet. Ce bloc ne
              // depend donc ni du code de retrait ni du statut du retrait :
              // il s'affiche des qu'un colis existe.
              if (r.numerosSuivi.isNotEmpty) _leSuivi(context, r),
              if (r.codeRetrait != null)
                _leCode(context, r)
              else if (r.remis)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    r.dateRetrait != null
                        ? 'Marchandise remise le ${_jour(r.dateRetrait!)}.'
                        : 'Marchandise remise.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: context.texteAttenue,
                    ),
                  ),
                ),
            ],

            if (_point != null) ...[
              _lePoint(context, _point!),
              const SizedBox(height: 18),
            ],

            const Libelle('Articles'),
            const SizedBox(height: 10),
            for (final l in c.lignes) _uneLigne(context, l, c.devise),

            const SizedBox(height: 18),
            _leRecapitulatif(context, c),

            if (c.statut == 'EN_ATTENTE_PAIEMENT') ...[
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EcranPaiement(commandeId: c.id),
                  ),
                ),
                child: const Text('Reprendre le paiement'),
              ),
            ],

            const SizedBox(height: 22),
            // ⚠️ Aucun bouton « annuler » après paiement, et ce n'est pas un
            //    oubli : le stock est engagé et l'acheminement peut être parti.
            //    Une règle métier invisible à l'écran ne protège de rien — elle
            //    produit des réclamations. On dit donc où s'adresser.
            Text(
              'Un problème avec cette commande ? Ouvrez une réclamation depuis '
              '« Mon compte » : un conseiller l’examine.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: context.texteAttenue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leSuivi(BuildContext context, _MonRetrait r) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: context.bordure),
      borderRadius: BorderRadius.circular(Jetons.rayonMoyen),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Libelle(
          r.numerosSuivi.length > 1 ? 'Suivi des colis' : 'Suivi du colis',
        ),
        for (final n in r.numerosSuivi)
          // On OUVRE le suivi, on ne se contente pas d'afficher le numero :
          // le recopier a la main dans le champ de l'autre ecran est la
          // premiere occasion de se tromper d'un caractere.
          InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => EcranSuivi(numero: n)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                n,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Jetons.primaire,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        Text(
          'Ce numero ouvre le trajet detaille. Il peut se transmettre : '
          'le consulter ne demande pas de compte.',
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: context.texteAttenue,
          ),
        ),
      ],
    ),
  );

  Widget _leCode(BuildContext context, _MonRetrait r) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Jetons.succes.withValues(alpha: 0.08),
      border: Border.all(color: Jetons.succes.withValues(alpha: 0.35)),
      borderRadius: BorderRadius.circular(Jetons.rayonMoyen),
    ),
    child: Column(
      children: [
        const Libelle('Votre code de retrait'),
        const SizedBox(height: 8),
        Text(
          r.codeRetrait!,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            // L'espacement sépare les caractères : un code se recopie signe par
            // signe, et deux lettres collées se lisent comme une seule.
            letterSpacing: 6,
            color: Jetons.succes,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Présentez ce code au point de récupération. Il vous sera demandé '
          'avant qu’on vous remette la marchandise.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.5,
            color: context.texteAttenue,
          ),
        ),
        // Deux marchands, deux envois : le dire, sinon on repart avec la
        // moitié de sa commande en croyant tout avoir.
        if (_retraits.length > 1) ...[
          const SizedBox(height: 8),
          Text(
            'Envoi ${r.numeroExpedition}',
            style: TextStyle(fontSize: 11.5, color: context.texteAttenue),
          ),
        ],
      ],
    ),
  );

  Widget _lePoint(BuildContext context, PointRecuperation p) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: context.bordure),
      borderRadius: BorderRadius.circular(Jetons.rayonMoyen),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Libelle('Point de récupération'),
        const SizedBox(height: 6),
        Text(
          p.nom,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
        Text(
          p.ville,
          style: TextStyle(fontSize: 13, color: context.texteAttenue),
        ),
        if (p.adresse != null && p.adresse!.isNotEmpty)
          Text(
            p.adresse!,
            style: TextStyle(fontSize: 12.5, color: context.texteAttenue),
          ),
        if (p.horaires != null && p.horaires!.isNotEmpty)
          Text(
            p.horaires!,
            style: TextStyle(fontSize: 12.5, color: context.texteAttenue),
          ),
      ],
    ),
  );

  Widget _uneLigne(BuildContext context, _LigneCommande l, String devise) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.designation,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${l.quantite} × ${montantLisible(l.prixUnitaire, devise)}',
                    style: TextStyle(fontSize: 12, color: context.texteAttenue),
                  ),
                ],
              ),
            ),
            Text(
              montantLisible(l.montantLigne, devise),
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );

  Widget _leRecapitulatif(BuildContext context, _Commande c) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: context.bordure),
      borderRadius: BorderRadius.circular(Jetons.rayonMoyen),
    ),
    child: Column(
      children: [
        _ligne(context, 'Articles', c.montantArticles, c.devise),
        const SizedBox(height: 6),
        _ligne(context, 'Frais d’acheminement', c.montantFrais, c.devise),
        if (c.montantRemise > 0) ...[
          const SizedBox(height: 6),
          _ligne(context, 'Remise', -c.montantRemise, c.devise),
        ],
        const Divider(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total payé',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            Text(
              montantLisible(c.montantTotal, c.devise),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _ligne(
    BuildContext context,
    String libelle,
    num valeur,
    String devise,
  ) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        libelle,
        style: TextStyle(fontSize: 13, color: context.texteAttenue),
      ),
      Text(
        montantLisible(valeur, devise),
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );

  static String _jour(DateTime d) {
    const mois = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    final l = d.toLocal();
    return '${l.day} ${mois[l.month - 1]} ${l.year}';
  }
}

/// Les statuts d'une commande, dits en français.
///
/// ⚠️ Partagé entre la liste et le détail : deux tables divergeraient, et le
///    même code s'afficherait « En route » d'un côté, « EXPEDIEE » de l'autre.
const statutsCommande = <String, ({String texte, Color? couleur})>{
  'EN_ATTENTE_PAIEMENT': (texte: 'À payer', couleur: Jetons.alerte),
  'PAYEE': (texte: 'Payée', couleur: Jetons.info),
  'EN_PREPARATION': (texte: 'En préparation', couleur: Jetons.info),
  'PRETE': (texte: 'Prête', couleur: Jetons.info),
  'EXPEDIEE': (texte: 'En route', couleur: Jetons.info),
  'DISPONIBLE': (texte: 'À retirer', couleur: Jetons.succes),
  'RETIREE': (texte: 'Retirée', couleur: null),
  'ANNULEE': (texte: 'Annulée', couleur: null),
};
