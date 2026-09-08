import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../charte/jetons.dart';
import '../charte/theme.dart';
import '../modeles/catalogue.dart';
import '../services/services.dart';
import '../widgets/communs.dart';
import 'connexion.dart';
import 'detail_commande.dart';
import 'favoris.dart';
import 'sav.dart';
import 'suivi.dart';

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

/// L'espace personnel.
///
/// ## ⚠️ Il attend la reprise de session avant de se dessiner
///
/// Sans cela, l'écran affiche « Se connecter » une demi-seconde à chaque
/// ouverture, sur un compte qui est en fait connecté — et on appuie dessus.
class EcranCompte extends StatefulWidget {
  const EcranCompte({super.key});

  @override
  State<EcranCompte> createState() => _EcranCompteState();
}

class _EcranCompteState extends State<EcranCompte> {
  List<_ResumeCommande> _commandes = const [];
  bool _chargement = false;
  String? _erreur;

  /// La session dont on a déjà chargé les commandes.
  ///
  /// Sans ce garde, chaque reconstruction relancerait la requête — et un écran
  /// qui se redessine souvent la relancerait souvent.
  int? _chargePour;

  Future<void> _charger() async {
    final services = Services.de(context);
    if (!services.session.connecte) return;

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      final page = PageDe.de(
        await services.api.obtenir('/api/commandes/miennes?taille=20'),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = Services.de(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Mon compte')),
      body: ListenableBuilder(
        listenable: services.session,
        builder: (context, _) {
          if (services.session.enCoursDeReprise) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!services.session.connecte) {
            _chargePour = null;
            return _horsSession(context);
          }

          final id = services.session.utilisateurId;
          if (_chargePour != id) {
            _chargePour = id;
            // Après le rendu : appeler setState pendant un build lèverait.
            WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
          }

          return _mesCommandes(context, services);
        },
      ),
    );
  }

  Widget _horsSession(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
    children: [
      const Text(
        'Suivez vos commandes',
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(
        'Votre compte garde vos commandes, vos retours et le code qui vous '
        'permet de retirer votre marchandise.',
        style: TextStyle(
          fontSize: 13.5,
          height: 1.5,
          color: context.texteAttenue,
        ),
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const EcranConnexion())),
        child: const Text('Se connecter'),
      ),
      const SizedBox(height: 24),
      const Divider(),
      const SizedBox(height: 16),
      // La seule chose utile SANS compte : elle a sa place ici, où
      // quelqu'un qui attend un colis viendra chercher.
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.local_shipping_outlined),
        title: const Text('Suivre un colis'),
        subtitle: const Text('Sans compte, avec votre numéro de suivi.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const EcranSuivi())),
      ),
    ],
  );

  Widget _mesCommandes(BuildContext context, Services services) {
    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      services.session.nom ?? 'Mon compte',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (services.session.email != null)
                      Text(
                        services.session.email!,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.texteAttenue,
                        ),
                      ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: services.session.deconnecter,
                child: const Text('Se déconnecter'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Libelle('Mes commandes'),
          const SizedBox(height: 10),
          if (_chargement)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_erreur != null)
            Alerte(message: _erreur!)
          else if (_commandes.isEmpty)
            Text(
              'Vous n’avez pas encore commandé.',
              style: TextStyle(fontSize: 13.5, color: context.texteAttenue),
            )
          else
            for (final c in _commandes) _uneCommande(context, c),
          const SizedBox(height: 12),
          const Divider(),
          _entree(
            context,
            icone: Icons.favorite_border,
            titre: 'Ma liste',
            ecran: () => const EcranFavoris(),
          ),
          _entree(
            context,
            icone: Icons.assignment_return_outlined,
            titre: 'Réclamations et retours',
            ecran: () => const EcranSav(),
          ),
          _entree(
            context,
            icone: Icons.forum_outlined,
            titre: 'Mes discussions',
            ecran: () => const EcranDiscussions(),
          ),
          _entree(
            context,
            icone: Icons.local_shipping_outlined,
            titre: 'Suivre un colis',
            ecran: () => const EcranSuivi(),
          ),
        ],
      ),
    );
  }

  /// Une entrée de l'espace personnel.
  ///
  /// Écrite une fois : quatre ListTile recopiés divergeraient au premier
  /// ajustement — l'un garderait sa flèche, l'autre non.
  Widget _entree(
    BuildContext context, {
    required IconData icone,
    required String titre,
    required Widget Function() ecran,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icone),
    title: Text(titre, style: const TextStyle(fontSize: 14.5)),
    trailing: const Icon(Icons.chevron_right),
    onTap: () =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ecran())),
  );

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
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EcranDetailCommande(commandeId: c.id),
          ),
        ),
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
              // ⚠️ Le CODE DE RETRAIT n'est pas dans cette liste, et ce n'est pas un
              //    oubli : c'est un secret partagé, qui suffit à emporter la
              //    marchandise. Ici, il apparaîtrait sur la capture d'écran qu'on
              //    envoie à un proche pour lui montrer ses achats.
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
