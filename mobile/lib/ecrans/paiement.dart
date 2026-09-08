import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../charte/jetons.dart';
import '../charte/theme.dart';
import '../modeles/catalogue.dart';
import '../services/services.dart';
import '../widgets/communs.dart';

class _EtatPaiement {
  const _EtatPaiement({
    required this.id,
    required this.statut,
    required this.montant,
    required this.referenceTransaction,
  });

  final int id;
  final String statut;
  final num montant;
  final String? referenceTransaction;

  factory _EtatPaiement.de(Map<String, dynamic> j) => _EtatPaiement(
    id: (j['id'] as num).toInt(),
    statut: (j['statut'] as String?) ?? '',
    montant: (j['montant'] as num?) ?? 0,
    referenceTransaction: j['referenceTransaction'] as String?,
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

  String _moyen = 'MTN_MOMO';
  _EtatPaiement? _paiement;

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
            })
            as Map<String, dynamic>,
      );
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _paiement = p;
      });
    } on ErreurApi catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _erreur = e.message;
      });
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
        // Confirmé pour de bon, par le SERVEUR — jamais deviné ici. Le panier
        // serveur est vidé par la commande ; le panier local, lui, l'a déjà
        // été à la fusion.
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
    const SizedBox(height: 8),
    Text(
      'Vous recevrez une demande de validation sur le téléphone associé à '
      'votre compte.',
      style: TextStyle(
        fontSize: 12.5,
        height: 1.45,
        color: context.texteAttenue,
      ),
    ),
    const SizedBox(height: 18),
    FilledButton(
      onPressed: _envoi ? null : _lancer,
      child: Text(_envoi ? 'Envoi…' : 'Lancer le paiement'),
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
