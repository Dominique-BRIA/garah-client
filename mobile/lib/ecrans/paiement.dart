import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../charte/jetons.dart';
import '../charte/theme.dart';
import '../modeles/catalogue.dart';
import '../services/services.dart';
import '../widgets/communs.dart';
import 'page_de_paiement.dart';

class _EtatPaiement {
  const _EtatPaiement({
    required this.id,
    required this.statut,
    required this.montant,
    required this.referenceTransaction,
    this.moyen,
    this.codeUssd,
    this.urlPaiement,
    this.urlRetour,
  });

  final int id;
  final String statut;
  final num montant;
  final String? referenceTransaction;

  /// `MTN_MOMO` ou `ORANGE_MONEY`. Nul avec MoneyFusion tant que le client
  /// ne l'a pas choisi sur la page de paiement (D-55).
  final String? moyen;

  /// MoneyFusion : la page où le client paie. Nulle avec Campay, et en
  /// dehors de la demande initiale.
  final String? urlPaiement;

  /// MoneyFusion : l'adresse vers laquelle la page renvoie le client. La
  /// page intégrée la guette pour se refermer.
  final String? urlRetour;

  /// Le code à composer si la demande n'arrive pas d'elle-même.
  ///
  /// ⚠️ Nul en dehors de la demande initiale : il n'est valable qu'à cet
  ///    instant. L'afficher plus tard ferait composer un code périmé.
  final String? codeUssd;

  factory _EtatPaiement.de(Map<String, dynamic> j) => _EtatPaiement(
    id: (j['id'] as num).toInt(),
    statut: (j['statut'] as String?) ?? '',
    montant: (j['montant'] as num?) ?? 0,
    referenceTransaction: j['referenceTransaction'] as String?,
    moyen: j['moyen'] as String?,
    codeUssd: j['codeUssd'] as String?,
    urlPaiement: j['urlPaiement'] as String?,
    urlRetour: j['urlRetour'] as String?,
  );

  bool get confirme => statut == 'CONFIRME';
  bool get echoue => statut == 'ECHOUE' || statut == 'ANNULE';
  bool get enAttente => !confirme && !echoue;
}

/// Le paiement mobile.
///
/// ## 🎯 JAMAIS DE SUCCÈS OPTIMISTE
///
/// Le client valide sur son téléphone ; GARAH l'apprend par un **webhook**
/// Campay qui peut mettre plusieurs secondes — ou ne jamais arriver.
///
/// Afficher « payé » avant confirmation ferait repartir un client persuadé
/// d'avoir réglé. Le litige qui suit coûte plus cher que l'attente.
///
/// D'où l'état d'attente explicite, le bouton qui redemande l'état à
/// l'opérateur, et une **sortie honnête** si rien n'arrive : la commande reste
/// en attente de paiement, rien n'est perdu.
///
/// ## ⚠️ Aucune interrogation automatique en boucle
///
/// Redemander toutes les deux secondes viderait la batterie et le forfait
/// pendant qu'on cherche son téléphone pour valider. C'est le client qui
/// appuie, quand il a fini — lui seul sait quand il a fini.
///
/// **Une exception bornée : le retour de la page MoneyFusion (D-55).** Là, on
/// SAIT que le client a fini — il vient de quitter la page. Mais le webhook
/// de MoneyFusion peut arriver après lui. On redemande donc l'état au plus six
/// fois, toutes les cinq secondes, puis le bouton prend le relais. Une
/// demi-minute, une fois, sur un événement certain : pas une boucle.
class EcranPaiement extends StatefulWidget {
  const EcranPaiement({super.key, required this.commandeId});

  final int commandeId;

  @override
  State<EcranPaiement> createState() => _EcranPaiementState();
}

class _EcranPaiementState extends State<EcranPaiement> {
  /// Les deux moyens que l'application accepte réellement. Rien d'autre n'est
  /// listé : proposer une carte bancaire promettrait un service inexistant.
  static const _moyens = <(String code, String libelle)>[
    ('MTN_MOMO', 'MTN Mobile Money'),
    ('ORANGE_MONEY', 'Orange Money'),
  ];

  static const _essaisAuRetour = 6;
  static const _intervalleAuRetour = Duration(seconds: 5);

  String _moyen = 'MTN_MOMO';
  _EtatPaiement? _paiement;

  /// Avant le clic : faut-il proposer MTN / Orange ? Voir
  /// `ServiceConfiguration.paiementParMoneyFusion`.
  bool _parMoneyFusion = false;

  /// La page MoneyFusion et son adresse de retour, gardées de la réponse
  /// initiale : les relectures d'état ne les renvoient pas, et le client doit
  /// pouvoir rouvrir une page fermée par erreur.
  String? _urlPaiement;
  String? _urlRetour;

  /// Le numéro qui recevra la demande de validation.
  final _telephone = TextEditingController();

  bool _numeroDemande = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ⚠️ ICI et non dans initState : Services.de() lit un InheritedWidget, ce
    //    qui est interdit avant que les dependances ne soient posees. Le
    //    garde-fou evite de redemander le profil a chaque fois que les
    //    dependances changent — un changement de theme suffirait.
    if (_numeroDemande) return;
    _numeroDemande = true;
    _prefillerLeNumero();
    _lireLeFournisseur();
  }

  /// Lu une seule fois pour toute l'application, et sans jamais lever.
  Future<void> _lireLeFournisseur() async {
    final configuration = Services.de(context).configuration;
    await configuration.charger();
    if (!mounted) return;
    setState(() => _parMoneyFusion = configuration.paiementParMoneyFusion);
  }

  @override
  void dispose() {
    _telephone.dispose();
    super.dispose();
  }

  /// Pré-remplit le numéro depuis le profil.
  ///
  /// ⚠️ Son échec ne se signale PAS. Le champ reste vide et se saisit à la
  ///    main : afficher une erreur ferait croire que le paiement est en panne
  ///    alors qu'il ne manque qu'une commodité. C'est la seule raison pour
  ///    laquelle on se permet d'avaler l'exception ici.
  Future<void> _prefillerLeNumero() async {
    try {
      final profil =
          await Services.de(context).api.obtenir('/api/profil')
              as Map<String, dynamic>;
      final numero = (profil['telephone'] as String?)?.trim();
      if (!mounted || numero == null || numero.isEmpty) return;
      // On n'écrase pas ce qui a déjà été tapé : la réponse peut arriver
      // après que le client a commencé à saisir.
      if (_telephone.text.isEmpty) {
        setState(() => _telephone.text = numero);
      }
    } catch (_) {
      // Voir la javadoc : volontairement muet.
    }
  }

  bool _envoi = false;
  bool _verification = false;
  String? _erreur;

  Future<void> _lancer() async {
    if (_envoi) return;
    setState(() {
      _envoi = true;
      _erreur = null;
    });

    try {
      final p = _EtatPaiement.de(
        await Services.de(context).api.poster('/api/paiements', {
              'commandeId': widget.commandeId,
              'moyen': _moyen,
              // ⚠️ Il MANQUAIT. Le serveur l exige — c est ce numero qui part
              //    chez l operateur et recevra la demande de validation — et
              //    le paiement echouait donc toujours.
              'telephone': _telephone.text.trim(),
            })
            as Map<String, dynamic>,
      );
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _paiement = p;
        if (p.urlPaiement != null) {
          _urlPaiement = p.urlPaiement;
          _urlRetour = p.urlRetour;
        }
      });
      // C'est la RÉPONSE qui décide, pas la configuration lue avant le clic.
      if (p.urlPaiement != null) {
        await _ouvrirLaPage();
      }
    } on ErreurApi catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
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
        _envoi = false;
        _erreur = 'Une erreur inattendue est survenue. Reessayez.';
      });
    }
  }

  /// Ouvre la page MoneyFusion, puis vérifie au retour (D-55).
  ///
  /// Qu'elle se referme sur l'adresse de retour ou que le client la ferme
  /// lui-même, on vérifie : dans les deux cas il a peut-être payé.
  Future<void> _ouvrirLaPage() async {
    final url = _urlPaiement;
    if (url == null) return;

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EcranPageDePaiement(url: url, urlRetour: _urlRetour),
      ),
    );
    if (!mounted) return;

    for (var essai = 0; essai < _essaisAuRetour; essai++) {
      if (essai > 0) {
        await Future<void>.delayed(_intervalleAuRetour);
        if (!mounted) return;
      }
      // Tranché, ou le client a appuyé sur « Réessayer » entre-temps : on
      // s'arrête, sans quoi on relirait un paiement abandonné.
      if (_paiement?.enAttente != true) return;
      await _verifier();
      if (!mounted || _paiement?.enAttente != true) return;
    }
  }

  /// Redemande l'état à l'opérateur.
  ///
  /// Sans attendre la réconciliation nocturne : le client est devant son
  /// écran, il vient de valider, et lui dire « revenez demain » n'est pas une
  /// réponse.
  Future<void> _verifier() async {
    final p = _paiement;
    if (p == null || _verification) return;
    setState(() {
      _verification = true;
      _erreur = null;
    });

    final messager = ScaffoldMessenger.of(context);
    try {
      final maj = _EtatPaiement.de(
        await Services.de(
              context,
            ).api.poster('/api/paiements/${p.id}/verification')
            as Map<String, dynamic>,
      );
      if (!mounted) return;
      setState(() {
        _verification = false;
        _paiement = maj;
      });

      if (maj.confirme) {
        // Confirmé pour de bon, par le SERVEUR — jamais deviné ici. Les deux
        // paniers sont déjà vides : celui du serveur, consommé par la commande ;
        // le local, vidé au moment où la commande est partie.
        messager.showSnackBar(
          const SnackBar(content: Text('Paiement confirmé. Merci !')),
        );
      }
    } on ErreurApi catch (e) {
      if (!mounted) return;
      setState(() {
        _verification = false;
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
        _verification = false;
        _erreur = 'Une erreur inattendue est survenue. Reessayez.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _paiement;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement'),
        // ⚠️ Pas de flèche de retour : revenir en arrière mènerait à l'écran de
        //    commande d'un panier déjà commandé, et on repasserait la même
        //    commande sans le vouloir.
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'Commande n° ${widget.commandeId}',
            style: TextStyle(fontSize: 13, color: context.texteAttenue),
          ),
          const SizedBox(height: 20),

          if (p == null)
            ..._avantLeLancement(context)
          else
            ..._apres(context, p),

          if (_erreur != null) ...[
            const SizedBox(height: 16),
            Alerte(message: _erreur!),
          ],
        ],
      ),
    );
  }

  List<Widget> _avantLeLancement(BuildContext context) => [
    const Libelle('Comment payer'),
    const SizedBox(height: 10),
    // D-55 : avec MoneyFusion, le client choisit MTN ou Orange SUR SA PAGE.
    // Le lui demander ici le ferait choisir deux fois — et rien ne
    // l'empêcherait de choisir Orange ici puis MTN là-bas.
    if (_parMoneyFusion)
      Text(
        'Vous choisirez MTN Mobile Money ou Orange Money sur la page de '
        'paiement sécurisée MoneyFusion, qui s’ouvrira dans l’application.',
        style: TextStyle(
          fontSize: 13.5,
          height: 1.5,
          color: context.texteAttenue,
        ),
      ),
    if (!_parMoneyFusion)
      for (final (code, libelle) in _moyens)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: code == _moyen
                ? Jetons.primaire.withValues(alpha: 0.07)
                : null,
            border: Border.all(
              color: code == _moyen ? Jetons.primaire : context.bordure,
            ),
            borderRadius: BorderRadius.circular(Jetons.rayonMoyen),
          ),
          child: InkWell(
            onTap: () => setState(() => _moyen = code),
            borderRadius: BorderRadius.circular(Jetons.rayonMoyen),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    code == _moyen
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: code == _moyen
                        ? Jetons.primaire
                        : context.texteAttenue,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    libelle,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    const SizedBox(height: 16),
    // ⚠️ LE NUMÉRO EST DEMANDÉ, ET IL DOIT L'ÊTRE.
    //
    //    L'écran promettait « le téléphone associé à votre compte » et
    //    n'envoyait AUCUN numéro. Le serveur en exige un — c'est lui qui part
    //    chez l'opérateur et qui recevra la demande de validation — et le
    //    paiement échouait donc toujours, sur un message qui n'expliquait
    //    rien : « Le numéro de téléphone est obligatoire. »
    //
    //    Il est PRÉ-REMPLI depuis le profil, mais reste modifiable : on paie
    //    souvent avec un autre numéro que celui du compte — celui d'un
    //    proche, ou son second opérateur. Le figer obligerait à changer son
    //    profil pour payer.
    Text(
      'Numéro Mobile Money',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: context.texteAttenue,
      ),
    ),
    const SizedBox(height: 8),
    TextField(
      controller: _telephone,
      keyboardType: TextInputType.phone,
      enabled: !_envoi,
      decoration: const InputDecoration(hintText: '+237 6 99 00 00 00'),
      onChanged: (_) => setState(() {}),
    ),
    const SizedBox(height: 8),
    Text(
      _parMoneyFusion
          ? 'Votre numéro, pour que MoneyFusion vous identifie.'
          : _moyen == 'MTN_MOMO'
          ? 'Ce numéro MTN recevra la demande de validation.'
          : 'Ce numéro Orange recevra la demande de validation.',
      style: TextStyle(
        fontSize: 12.5,
        height: 1.45,
        color: context.texteAttenue,
      ),
    ),
    const SizedBox(height: 18),
    FilledButton(
      // ⚠️ Désactivé tant que le numéro est vide, plutôt que de laisser partir
      //    un appel dont on connaît déjà le refus. Un aller-retour réseau pour
      //    apprendre ce qu'on savait avant de l'envoyer, sur un forfait
      //    compté, n'est pas gratuit.
      onPressed: _envoi || _telephone.text.trim().isEmpty ? null : _lancer,
      child: Text(
        _envoi
            ? 'Envoi…'
            : _parMoneyFusion
            ? 'Continuer vers le paiement'
            : 'Lancer le paiement',
      ),
    ),
  ];

  List<Widget> _apres(BuildContext context, _EtatPaiement p) {
    if (p.confirme) {
      return [
        _bandeau(
          context,
          couleur: Jetons.succes,
          icone: Icons.check_circle_outline,
          titre: 'Paiement confirmé',
          texte:
              'Votre commande est enregistrée. Vous serez prévenu lorsque la '
              'marchandise sera disponible au point de récupération.',
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          child: const Text('Retour à la boutique'),
        ),
      ];
    }

    if (p.echoue) {
      return [
        _bandeau(
          context,
          couleur: Jetons.danger,
          icone: Icons.error_outline,
          titre: 'Paiement non abouti',
          // ⚠️ On dit ce qui N'A PAS été perdu. Sans cette phrase, le client
          //    croit devoir tout recommencer, et souvent repasse une seconde
          //    commande.
          texte:
              'Votre commande est conservée telle quelle. Vous pouvez '
              'reprendre le paiement quand vous voulez.',
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () => setState(() {
            _paiement = null;
            _erreur = null;
          }),
          child: const Text('Réessayer'),
        ),
      ];
    }

    // D-55 : retour de la page MoneyFusion. Rien à valider sur le téléphone,
    // on attend la confirmation. Le moyen est nul tant que MoneyFusion ne
    // l'a pas confirmé — c'est ce qui distingue ce cas de Campay.
    if (p.moyen == null && (p.codeUssd == null || p.codeUssd!.isEmpty)) {
      return [
        _bandeau(
          context,
          couleur: Jetons.alerte,
          icone: Icons.hourglass_top_outlined,
          titre: 'Vérification de votre paiement',
          texte:
              'Nous attendons la confirmation de MoneyFusion. Cela prend en '
              'général quelques secondes. Le montant est de '
              '${montantLisible(p.montant)}.',
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _verification ? null : _verifier,
          child: Text(_verification ? 'Vérification…' : 'Vérifier maintenant'),
        ),
        // Le client a pu fermer la page par erreur, avant d'avoir payé.
        if (_urlPaiement != null) ...[
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _verification ? null : _ouvrirLaPage,
            child: const Text('Rouvrir la page de paiement'),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'Si rien ne se passe, ne recommencez pas la commande : elle reste '
          'enregistrée et vous la retrouverez dans « Mon compte », prête à '
          'être payée.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.5,
            color: context.texteAttenue,
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          child: const Text('Revenir à la boutique'),
        ),
      ];
    }

    return [
      _bandeau(
        context,
        couleur: Jetons.alerte,
        icone: Icons.hourglass_top_outlined,
        titre: 'En attente de votre validation',
        texte:
            'Validez la demande sur votre téléphone, puis revenez ici. '
            'Le montant est de ${montantLisible(p.montant)}.',
      ),
      // 🎯 LE RECOURS QUAND LA DEMANDE N'ARRIVE PAS.
      //
      //    L'opérateur pousse une demande de validation sur le téléphone.
      //    Elle arrive presque toujours — mais quand elle se perd, le client
      //    reste devant un écran qui dit « validez sur votre téléphone »,
      //    sans rien à valider.
      //
      //    Le code voyageait déjà dans la réponse et n'était affiché nulle
      //    part.
      if (p.codeUssd != null && p.codeUssd!.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(
          'Rien reçu ? Composez ${p.codeUssd} sur ce téléphone.',
          style: TextStyle(fontSize: 13, color: context.texteAttenue),
        ),
      ],
      if (p.referenceTransaction != null) ...[
        const SizedBox(height: 12),
        Text(
          'Référence : ${p.referenceTransaction}',
          style: TextStyle(fontSize: 12, color: context.texteAttenue),
        ),
      ],
      const SizedBox(height: 18),
      FilledButton(
        onPressed: _verification ? null : _verifier,
        child: Text(_verification ? 'Vérification…' : 'J’ai validé, vérifier'),
      ),
      const SizedBox(height: 20),
      // La SORTIE HONNÊTE. Sans elle, un client dont le paiement n'arrive
      // jamais reste bloqué sur cet écran sans savoir quoi faire.
      Text(
        'Si rien ne se passe, ne recommencez pas la commande : elle reste '
        'enregistrée et vous la retrouverez dans « Mon compte », prête à être '
        'payée.',
        style: TextStyle(
          fontSize: 12.5,
          height: 1.5,
          color: context.texteAttenue,
        ),
      ),
      const SizedBox(height: 10),
      OutlinedButton(
        onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        child: const Text('Revenir à la boutique'),
      ),
    ];
  }

  Widget _bandeau(
    BuildContext context, {
    required Color couleur,
    required IconData icone,
    required String titre,
    required String texte,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: couleur.withValues(alpha: 0.08),
      border: Border.all(color: couleur.withValues(alpha: 0.3)),
      borderRadius: BorderRadius.circular(Jetons.rayonMoyen),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icone, color: couleur, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                titre,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: couleur,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(texte, style: const TextStyle(fontSize: 13.5, height: 1.5)),
      ],
    ),
  );
}
