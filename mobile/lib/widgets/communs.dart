import 'package:flutter/material.dart';

import '../charte/jetons.dart';
import '../charte/theme.dart';
import '../modeles/catalogue.dart';

/// Une vignette de produit.
///
/// Écrite une fois et posée partout — accueil, catalogue, liste d'envies. Trois
/// copies divergeraient au premier ajout : l'une afficherait la catégorie,
/// l'autre non, et personne ne saurait laquelle a raison.
class VignetteProduit extends StatelessWidget {
  const VignetteProduit({
    super.key,
    required this.produit,
    required this.surAppui,
  });

  final ResumeProduit produit;
  final VoidCallback surAppui;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: surAppui,
      borderRadius: BorderRadius.circular(Jetons.rayonMoyen),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: context.bordure),
          borderRadius: BorderRadius.circular(Jetons.rayonMoyen),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: PhotoProduit(url: produit.urlPhotoPrincipale),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (produit.categorieNom != null)
                    Text(
                      produit.categorieNom!.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: context.texteAttenue,
                      ),
                    ),
                  Text(
                    produit.nom,
                    // Deux lignes au plus : au-delà, les cartes de la grille ne
                    // s'alignent plus et la colonne devient irrégulière.
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (produit.marchandNom != null)
                    Text(
                      produit.marchandNom!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.texteAttenue,
                      ),
                    ),
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        'dès ',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.texteAttenue,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          montantLisible(produit.prixMin, produit.devise),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Un article épuisé reste VISIBLE : le masquer ferait croire
                  // qu'il n'existe pas, et chercher ailleurs.
                  if (produit.quantiteDisponible == 0)
                    const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Etiquette(texte: 'Épuisé', couleur: null),
                    )
                  else if (produit.quantiteDisponible <= 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Etiquette(
                        texte: 'Plus que ${produit.quantiteDisponible}',
                        couleur: Jetons.alerte,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La photo d'un produit, ou sa silhouette.
///
/// ⚠️ `errorBuilder` n'est pas décoratif : les images viennent d'URL signées
///    qui expirent. Sans lui, une URL périmée laisse une zone grise avec une
///    icône de rupture système, qui ressemble à une application cassée.
class PhotoProduit extends StatelessWidget {
  const PhotoProduit({
    super.key,
    required this.url,
    this.ajustement = BoxFit.cover,
  });

  final String? url;
  final BoxFit ajustement;

  @override
  Widget build(BuildContext context) {
    final fond = Color.alphaBlend(
      Jetons.primaire.withValues(alpha: 0.06),
      Theme.of(context).colorScheme.surface,
    );

    if (url == null) {
      return _silhouette(fond);
    }

    return Image.network(
      url!,
      fit: ajustement,
      errorBuilder: (_, _, _) => _silhouette(fond),
      loadingBuilder: (contexte, enfant, progression) =>
          progression == null ? enfant : ColoredBox(color: fond),
    );
  }

  Widget _silhouette(Color fond) => ColoredBox(
    color: fond,
    child: Center(
      child: Icon(
        Icons.inventory_2_outlined,
        size: 34,
        color: Jetons.primaire.withValues(alpha: 0.4),
      ),
    ),
  );
}

/// Une étiquette d'état. [couleur] nulle = neutre.
class Etiquette extends StatelessWidget {
  const Etiquette({super.key, required this.texte, required this.couleur});

  final String texte;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final teinte = couleur ?? context.texteAttenue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: teinte.withValues(alpha: 0.12),
        border: Border.all(color: teinte.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texte.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: teinte,
        ),
      ),
    );
  }
}

/// Un écran qui n'a rien à montrer, ou qui a échoué.
///
/// Toujours avec une SORTIE : un cul-de-sac oblige à fermer l'application, et
/// on ne la rouvre pas toujours.
class EtatVide extends StatelessWidget {
  const EtatVide({
    super.key,
    required this.message,
    this.detail,
    this.libelleAction,
    this.surAction,
  });

  final String message;
  final String? detail;
  final String? libelleAction;
  final VoidCallback? surAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: context.texteAttenue,
                ),
              ),
            ],
            if (libelleAction != null && surAction != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(onPressed: surAction, child: Text(libelleAction!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Un message d'erreur bloquant, dans le ton du reste.
class Alerte extends StatelessWidget {
  const Alerte({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Jetons.danger.withValues(alpha: 0.08),
        border: Border.all(color: Jetons.danger.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(Jetons.rayonPetit),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 13.5,
          height: 1.45,
          color: Jetons.danger,
        ),
      ),
    );
  }
}

/// Le libellé d'un bloc, en petites capitales — comme sur le web.
class Libelle extends StatelessWidget {
  const Libelle(this.texte, {super.key});

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Text(
      texte.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: context.texteAttenue,
      ),
    );
  }
}
