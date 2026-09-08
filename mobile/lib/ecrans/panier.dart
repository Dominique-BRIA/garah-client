import 'package:flutter/material.dart';

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
    final services = Services.de(context);

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
            SizedBox(
              width: double.infinity,
              child: ListenableBuilder(
                listenable: services.session,
                builder: (context, _) => FilledButton(
                  onPressed: () {
                    // 🎯 La connexion arrive ICI, jamais avant. On remplit son
                    //    panier sans compte ; l'exiger au premier « Ajouter »
                    //    ferait fuir. C'est aussi le moment où le panier local
                    //    fusionne avec celui du serveur.
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => services.session.connecte
                            ? const EcranCommande()
                            : const EcranConnexion(),
                      ),
                    );
                  },
                  child: Text(
                    services.session.connecte
                        ? 'Passer commande'
                        : 'Se connecter pour commander',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
