import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../charte/jetons.dart';
import '../charte/theme.dart';
import '../modeles/catalogue.dart';
import '../services/panier_local.dart';
import '../services/services.dart';
import '../widgets/communs.dart';
import 'commande.dart';
import 'connexion.dart';

/// Le panier.
///
/// ## ⚠️ Le total affiché ici n'est PAS ce qu'on paiera
///
/// Il manque les **frais d'acheminement**, qui dépendent du point de
/// récupération choisi — et ce choix n'a pas encore été fait. Afficher ce
/// sous-total comme un total serait un mensonge découvert à l'écran suivant,
/// au pire moment.
///
/// ## Le panier vit dans le téléphone
///
/// On le remplit sans compte ; la connexion arrive au moment de commander, et
/// c'est là que ce panier fusionne avec celui du serveur.
class EcranPanier extends StatelessWidget {
  const EcranPanier({super.key});

  @override
  Widget build(BuildContext context) {
    final services = Services.de(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Mon panier')),
      body: ListenableBuilder(
        listenable: services.panier,
        builder: (context, _) {
          final lignes = services.panier.lignes;
          if (lignes.isEmpty) {
            return const EtatVide(
              message: 'Votre panier est vide.',
              detail:
                  'Les articles que vous ajoutez vous attendent ici, '
                  'même après avoir fermé l’application.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: lignes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _Ligne(ligne: lignes[i]),
          );
        },
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: services.panier,
        builder: (context, _) {
          if (services.panier.lignes.isEmpty) return const SizedBox.shrink();
          return _Recapitulatif(panier: services.panier);
        },
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.ligne});

  final LigneLocale ligne;

  @override
  Widget build(BuildContext context) {
    final panier = Services.de(context).panier;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: context.bordure),
        borderRadius: BorderRadius.circular(Jetons.rayonMoyen),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Jetons.rayonPetit),
            child: SizedBox(
              width: 66,
              height: 66,
              child: PhotoProduit(url: ligne.urlPhoto),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ligne.nomProduit,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (ligne.libelleDeclinaison != null)
                  Text(
                    ligne.libelleDeclinaison!,
                    style: TextStyle(fontSize: 12, color: context.texteAttenue),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _Compteur(
                      valeur: ligne.quantite,
                      surChangement: (q) =>
                          panier.changerQuantite(ligne.varianteId, q),
                    ),
                    const Spacer(),
                    Text(
                      montantLisible(
                        (ligne.prixIndicatif ?? 0) * ligne.quantite,
                      ),
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => panier.retirer(ligne.varianteId),
            tooltip: 'Retirer',
            icon: Icon(Icons.close, size: 20, color: context.texteAttenue),
          ),
        ],
      ),
    );
  }
}

class _Compteur extends StatelessWidget {
  const _Compteur({required this.valeur, required this.surChangement});

  final int valeur;
  final void Function(int) surChangement;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.bordure),
        borderRadius: BorderRadius.circular(Jetons.rayonPetit),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            // Retirer la dernière unité SUPPRIME la ligne : c'est ce qu'on
            // veut dire en descendant à zéro, et laisser une ligne à zéro
            // oblige à chercher un second geste.
            onTap: () => surChangement(valeur - 1),
            child: const SizedBox(
              width: 34,
              height: 34,
              child: Icon(Icons.remove, size: 17),
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              '$valeur',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          InkWell(
            onTap: () => surChangement(valeur + 1),
            child: const SizedBox(
              width: 34,
              height: 34,
              child: Icon(Icons.add, size: 17),
            ),
          ),
        ],
      ),
    );
  }
}

class _Recapitulatif extends StatelessWidget {
  const _Recapitulatif({required this.panier});

  final PanierLocal panier;

  @override
  Widget build(BuildContext context) {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sous-total (${panier.nombreArticles} article(s))',
                  style: TextStyle(fontSize: 13, color: context.texteAttenue),
                ),
                Text(
                  montantLisible(panier.sousTotal),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 🎯 DIRE CE QUI MANQUE AVANT LE CLIC. Les frais d'acheminement
            //    s'ajoutent au moment où l'on choisit son point de retrait :
            //    les découvrir à l'écran suivant fait renoncer.
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Les frais d’acheminement s’ajoutent une fois le point de '
                'récupération choisi.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: context.texteAttenue,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const SizedBox(width: double.infinity, child: _BoutonCommander()),
          ],
        ),
      ),
    );
  }
}

/// Le bouton qui mène à la commande.
///
/// ## ⚠️ IL SYNCHRONISE LE PANIER AVANT DE PARTIR
///
/// L'écran de commande lit le panier du SERVEUR, seul juge du stock et du
/// prix. Le panier local, lui, ne partait qu'à la connexion : quelqu'un déjà
/// connecté qui ajoutait un article ne l'envoyait nulle part, et l'écran
/// suivant annonçait « Votre panier est vide » sur un panier qui affichait un
/// article et son montant.
///
/// ## ⚠️ Un widget à état, pour une seule raison
///
/// La synchronisation est un appel réseau. Sans état, on ne pourrait ni
/// désactiver le bouton pendant l'envoi — deux tapes donneraient deux
/// commandes — ni dire pourquoi rien ne se passe quand le réseau est lent.
class _BoutonCommander extends StatefulWidget {
  const _BoutonCommander();

  @override
  State<_BoutonCommander> createState() => _BoutonCommanderState();
}

class _BoutonCommanderState extends State<_BoutonCommander> {
  bool _envoi = false;

  Future<void> _continuer() async {
    final services = Services.de(context);
    final navigateur = Navigator.of(context);
    final messager = ScaffoldMessenger.of(context);

    // 🎯 La connexion arrive ICI, jamais avant. On remplit son panier sans
    //    compte ; l'exiger au premier « Ajouter » ferait fuir. La
    //    synchronisation se fera juste après, à la connexion.
    if (!services.session.connecte) {
      navigateur.push(
        MaterialPageRoute(builder: (_) => const EcranConnexion()),
      );
      return;
    }

    setState(() => _envoi = true);
    try {
      await services.session.synchroniserLePanier();
    } on ErreurApi catch (e) {
      if (!mounted) return;
      setState(() => _envoi = false);
      // ⚠️ On NE PART PAS. L'écran de commande afficherait un panier vide ou
      //    incomplet, et le client croirait avoir perdu son panier. Mieux vaut
      //    rester ici, où il le voit, et dire que le réseau n'a pas suivi.
      messager.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _envoi = false);
      messager.showSnackBar(
        const SnackBar(
          content: Text('Votre panier n’a pas pu être envoyé. Réessayez.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _envoi = false);
    navigateur.push(MaterialPageRoute(builder: (_) => const EcranCommande()));
  }

  @override
  Widget build(BuildContext context) {
    final session = Services.de(context).session;

    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => FilledButton(
        onPressed: _envoi ? null : _continuer,
        child: _envoi
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                session.connecte
                    ? 'Passer commande'
                    : 'Se connecter pour commander',
              ),
      ),
    );
  }
}
