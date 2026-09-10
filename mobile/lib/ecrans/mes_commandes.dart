import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../charte/jetons.dart';
import '../charte/theme.dart';
import '../modeles/catalogue.dart';
import '../services/services.dart';
import '../widgets/communs.dart';
import 'catalogue.dart';
import 'detail_commande.dart';

/// Un résumé de commande, tel que la liste l'affiche.
class _ResumeCommande {
  const _ResumeCommande({
    required this.id,
    required this.numero,
    required this.statut,
    required this.montantTotal,
    required this.devise,
    required this.nombreLignes,
  });

  final int id;
  final String numero;
  final String statut;
  final num montantTotal;
  final String devise;
  final int nombreLignes;

  factory _ResumeCommande.de(Map<String, dynamic> j) => _ResumeCommande(
    id: (j['id'] as num).toInt(),
    numero: (j['numero'] as String?) ?? '',
    statut: (j['statut'] as String?) ?? '',
    montantTotal: (j['montantTotal'] as num?) ?? 0,
    devise: (j['devise'] as String?) ?? 'XAF',
    nombreLignes: (j['lignes'] as List<dynamic>?)?.length ?? 0,
  );
}

/// Mes commandes.
///
/// ## 🎯 Un écran à part, et plus une liste au milieu de « Mon compte »
///
/// Les commandes s'affichaient dans l'espace personnel, entre l'en-tête et les
/// autres rubriques. Vingt cartes empilées repoussaient « Ma liste » et « Mes
/// discussions » tout en bas, hors de l'écran : on les croyait absentes.
///
/// Elles ont maintenant leur écran, comme « Ma liste » — et comme sur le web,
/// où `/mes-commandes` joue le même rôle.
///
/// ## ⚠️ Le code de retrait n'est PAS dans cette liste
///
/// C'est un secret partagé, qui suffit à emporter la marchandise. Ici, il
/// apparaîtrait sur la capture d'écran qu'on envoie à un proche pour lui
/// montrer ses achats. Il se lit sur la fiche d'une commande arrivée.
class EcranMesCommandes extends StatefulWidget {
  const EcranMesCommandes({super.key});

  @override
  State<EcranMesCommandes> createState() => _EcranMesCommandesState();
}

class _EcranMesCommandesState extends State<EcranMesCommandes> {
  List<_ResumeCommande> _commandes = const [];
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

    try {
      // 25 et non 20 : la même taille de page que le web, pour qu'une même
      // personne voie la même liste d'un appareil à l'autre.
      final page = PageDe.de(
        await Services.de(
          context,
        ).api.obtenir('/api/commandes/miennes?taille=25'),
        _ResumeCommande.de,
      );
      if (!mounted) return;
      setState(() {
        _commandes = page.contenu;
        _chargement = false;
      });
    } on ErreurApi catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.message;
      });
    } catch (_) {
      // 🎯 LE FILET. Tout ce qui casse APRÈS la réponse — un champ absent, un
      //    cast qui échoue — lève autre chose qu'`ErreurApi`. Sans cette
      //    branche l'exception s'échappe, l'indicateur d'attente reste armé,
      //    et l'écran tourne indéfiniment SANS message.
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = 'Une erreur inattendue est survenue. Réessayez.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes commandes')),
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
    if (_commandes.isEmpty) {
      return EtatVide(
        message: 'Vous n’avez pas encore commandé.',
        detail:
            'Vos commandes apparaîtront ici, avec leur état, du paiement '
            'jusqu’au retrait.',
        libelleAction: 'Parcourir le catalogue',
        surAction: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const EcranCatalogue())),
      );
    }

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [for (final c in _commandes) _uneCommande(context, c)],
      ),
    );
  }

  Widget _uneCommande(BuildContext context, _ResumeCommande c) {
    final etat = statutsCommande[c.statut];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: context.bordure),
        borderRadius: BorderRadius.circular(Jetons.rayonMoyen),
      ),
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EcranDetailCommande(commandeId: c.id),
            ),
          );
          // L'état a pu changer pendant qu'on regardait la fiche — un
          // paiement repris, une marchandise arrivée. Revenir sur une étiquette
          // périmée ferait croire que rien n'a bougé.
          if (mounted) _charger();
        },
        borderRadius: BorderRadius.circular(Jetons.rayonMoyen),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      c.numero,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Etiquette(
                    texte: etat?.texte ?? c.statut,
                    couleur: etat?.couleur,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${c.nombreLignes} article(s) · ${montantLisible(c.montantTotal, c.devise)}',
                style: TextStyle(fontSize: 12.5, color: context.texteAttenue),
              ),
              if (c.statut == 'DISPONIBLE') ...[
                const SizedBox(height: 8),
                Text(
                  'Votre marchandise vous attend. Ouvrez la commande pour voir '
                  'votre code de retrait.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: Jetons.succes,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
