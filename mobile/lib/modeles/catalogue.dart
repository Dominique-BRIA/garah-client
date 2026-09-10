/// Les types du catalogue, recopiés des records du serveur.
///
/// La copie est ASSUMÉE : engendrer depuis Spring serait un chantier à lui
/// seul pour une poignée de records. Une divergence se voit au premier appel —
/// le champ manquant vaut `null` et l'écran l'affiche vide.
library;

/// Une page renvoyée par Spring Data.
class PageDe<T> {
  const PageDe({
    required this.contenu,
    required this.total,
    required this.derniere,
  });

  final List<T> contenu;
  final int total;
  final bool derniere;

  factory PageDe.de(dynamic json, T Function(Map<String, dynamic>) lire) {
    final carte = json as Map<String, dynamic>;
    final page = carte['page'] as Map<String, dynamic>?;
    final numero = (page?['number'] as num?)?.toInt() ?? 0;
    final pages = (page?['totalPages'] as num?)?.toInt() ?? 1;
    return PageDe(
      contenu: (carte['content'] as List<dynamic>)
          .map((e) => lire(e as Map<String, dynamic>))
          .toList(),
      total: (page?['totalElements'] as num?)?.toInt() ?? 0,
      derniere: numero >= pages - 1,
    );
  }
}

/// Un produit dans une liste. `GET /api/produits`
class ResumeProduit {
  const ResumeProduit({
    required this.id,
    required this.nom,
    required this.slug,
    required this.urlPhotoPrincipale,
    required this.marchandNom,
    required this.categorieNom,
    required this.prixMin,
    required this.devise,
    required this.quantiteDisponible,
  });

  final int id;
  final String nom;
  final String slug;
  final String? urlPhotoPrincipale;
  final String? marchandNom;
  final String? categorieNom;

  /// Le plus petit prix, tous paliers et déclinaisons confondus.
  /// Nul tant qu'aucun tarif n'est posé.
  final num? prixMin;
  final String devise;

  /// Somme sur toutes les déclinaisons : une taille épuisée n'épuise pas le
  /// produit.
  final int quantiteDisponible;

  factory ResumeProduit.de(Map<String, dynamic> j) => ResumeProduit(
    id: (j['id'] as num).toInt(),
    nom: j['nom'] as String,
    slug: j['slug'] as String,
    urlPhotoPrincipale: j['urlPhotoPrincipale'] as String?,
    marchandNom: j['marchandNom'] as String?,
    categorieNom: j['categorieNom'] as String?,
    prixMin: j['prixMin'] as num?,
    devise: (j['devise'] as String?) ?? 'XAF',
    quantiteDisponible: (j['quantiteDisponible'] as num?)?.toInt() ?? 0,
  );
}

/// Une place au classement des tendances. `GET /api/produits/tendance`
///
/// ⚠️ CE N'EST PAS UN PRODUIT. La route vient du module de mesure : ni photo,
///    ni prix, ni slug. Pour dessiner une vignette il faut compléter avec
///    `GET /api/produits/par-ids`.
class ProduitTendance {
  const ProduitTendance({required this.produitId, required this.nom});

  final int produitId;
  final String nom;

  factory ProduitTendance.de(Map<String, dynamic> j) => ProduitTendance(
    produitId: (j['produitId'] as num).toInt(),
    nom: j['nom'] as String,
  );
}

/// Un palier de prix — la « ladder pricing » d'Alibaba.
///
/// [quantiteMax] nul signifie « et au-delà ».
class PalierPrix {
  const PalierPrix({
    required this.quantiteMin,
    required this.quantiteMax,
    required this.prixUnitaire,
  });

  final int quantiteMin;
  final int? quantiteMax;
  final num prixUnitaire;

  factory PalierPrix.de(Map<String, dynamic> j) => PalierPrix(
    quantiteMin: (j['quantiteMin'] as num).toInt(),
    quantiteMax: (j['quantiteMax'] as num?)?.toInt(),
    prixUnitaire: j['prixUnitaire'] as num,
  );

  /// « 6 – 11 », ou « 48 et + » pour le dernier palier.
  String get plage =>
      quantiteMax == null ? '$quantiteMin et +' : '$quantiteMin – $quantiteMax';

  bool couvre(int quantite) =>
      quantite >= quantiteMin &&
      (quantiteMax == null || quantite <= quantiteMax!);
}

/// Une déclinaison achetable.
class Declinaison {
  const Declinaison({
    required this.id,
    required this.libelle,
    required this.paliers,
    required this.disponible,
    required this.quantiteMinimale,
  });

  final int id;
  final String libelle;

  /// Vide = aucun tarif paramétré. La déclinaison n'est alors PAS achetable.
  final List<PalierPrix> paliers;
  final int disponible;

  /// Le plus petit palier de la grille — le MOQ d'Alibaba.
  final int quantiteMinimale;

  factory Declinaison.de(Map<String, dynamic> j) => Declinaison(
    id: (j['id'] as num).toInt(),
    libelle: j['libelle'] as String,
    paliers: (j['paliers'] as List<dynamic>? ?? [])
        .map((e) => PalierPrix.de(e as Map<String, dynamic>))
        .toList(),
    disponible: (j['disponible'] as num?)?.toInt() ?? 0,
    quantiteMinimale: (j['quantiteMinimale'] as num?)?.toInt() ?? 1,
  );

  /// Achetable : il faut UN PRIX **et** DU STOCK.
  ///
  /// ⚠️ Les deux, pas seulement le stock. Une déclinaison en rayon mais sans
  ///    tarif se laisserait mettre au panier et échouerait au paiement — au
  ///    pire moment, quand le client a déjà sorti son téléphone.
  bool get achetable => paliers.isNotEmpty && disponible > 0;

  /// Le palier qui s'applique à cette quantité, ou nul si aucun ne la couvre.
  PalierPrix? palierPour(int quantite) {
    for (final p in paliers) {
      if (p.couvre(quantite)) return p;
    }
    return null;
  }

  /// Ce qu'on gagnerait à monter d'un palier.
  ///
  /// Nul s'il n'y en a pas, ou si le stock ne suit pas : promettre un tarif
  /// indisponible est pire que se taire.
  PalierPrix? palierSuivant(int quantite) {
    for (final p in paliers) {
      if (p.quantiteMin > quantite) {
        return p.quantiteMin > disponible ? null : p;
      }
    }
    return null;
  }
}

class MediaProduit {
  const MediaProduit({
    required this.id,
    required this.url,
    required this.principal,
    required this.ordre,
  });

  final int id;
  final String url;
  final bool principal;
  final int ordre;

  factory MediaProduit.de(Map<String, dynamic> j) => MediaProduit(
    id: (j['id'] as num).toInt(),
    url: j['url'] as String,
    principal: (j['principal'] as bool?) ?? false,
    ordre: (j['ordre'] as num?)?.toInt() ?? 0,
  );
}

/// La fiche telle que la vitrine l'affiche.
///
/// ⚠️ Distincte de la fiche d'administration, et pas par confort : celle-ci
///    porte la GRILLE DE PRIX et la DISPONIBILITÉ, sans quoi le prix change
///    entre la fiche et le panier — et ça ressemble à une arnaque.
class FicheVitrine {
  const FicheVitrine({
    required this.id,
    required this.nom,
    required this.slug,
    required this.description,
    required this.tauxTva,
    required this.marchandNom,
    required this.categorieNom,
    required this.declinaisons,
    required this.medias,
  });

  final int id;
  final String nom;
  final String slug;
  final String? description;
  final num tauxTva;

  /// Nul si le marchand a disparu : l'écran écrit « vendeur inconnu ».
  final String? marchandNom;
  final String? categorieNom;
  final List<Declinaison> declinaisons;
  final List<MediaProduit> medias;

  factory FicheVitrine.de(Map<String, dynamic> j) {
    final categorie = j['categorie'] as Map<String, dynamic>?;
    final medias =
        (j['medias'] as List<dynamic>? ?? [])
            .map((e) => MediaProduit.de(e as Map<String, dynamic>))
            .toList()
          // La principale d'abord : c'est la couverture, et c'est elle qui part au
          // panier quelle que soit la photo regardée.
          ..sort((a, b) {
            final parPrincipal = (b.principal ? 1 : 0) - (a.principal ? 1 : 0);
            return parPrincipal != 0
                ? parPrincipal
                : a.ordre.compareTo(b.ordre);
          });

    return FicheVitrine(
      id: (j['id'] as num).toInt(),
      nom: j['nom'] as String,
      slug: j['slug'] as String,
      description: j['description'] as String?,
      tauxTva: (j['tauxTva'] as num?) ?? 0,
      marchandNom: j['marchandNom'] as String?,
      categorieNom: categorie?['nom'] as String?,
      declinaisons: (j['declinaisons'] as List<dynamic>? ?? [])
          .map((e) => Declinaison.de(e as Map<String, dynamic>))
          .toList(),
      medias: medias,
    );
  }
}

class Categorie {
  const Categorie({
    required this.id,
    required this.nom,
    required this.parentId,
    this.enfants = const [],
  });

  final int id;
  final String nom;
  final int? parentId;

  /// Les sous-catégories.
  ///
  /// ⚠️ Le champ EXISTAIT côté serveur et n'était pas lu ici : l'accueil
  ///    écartait tout ce qui avait un parent, et une sous-catégorie créée au
  ///    back-office restait invisible.
  final List<Categorie> enfants;

  factory Categorie.de(Map<String, dynamic> j) => Categorie(
    id: (j['id'] as num).toInt(),
    nom: j['nom'] as String,
    parentId: (j['parentId'] as num?)?.toInt(),
    enfants: ((j['enfants'] as List<dynamic>?) ?? const [])
        .map((e) => Categorie.de(e as Map<String, dynamic>))
        .toList(),
  );
}

/// Une catégorie et sa profondeur dans l'arbre.
class CategorieAplatie {
  const CategorieAplatie(this.categorie, this.niveau);
  final Categorie categorie;

  /// 0 pour une racine. ⚠️ Sert à dessiner une puce d'enfant plus discrète :
  /// sans cela « Informatique » et « Electronique » se ressemblent alors que
  /// l'une contient l'autre.
  final int niveau;
}

/// L'arbre aplati — parents PUIS enfants, dans l'ordre.
List<CategorieAplatie> categoriesAplaties(
  List<Categorie> arbre, [
  int niveau = 0,
]) => [
  for (final c in arbre) ...[
    CategorieAplatie(c, niveau),
    ...categoriesAplaties(c.enfants, niveau + 1),
  ],
];

/// Un montant lisible : « 106 000 FCFA ».
///
/// L'espace insécable étroit sépare les milliers sans que le nombre se coupe
/// en fin de ligne.
String montantLisible(num? valeur, [String devise = 'XAF']) {
  if (valeur == null) return '—';

  final entier = valeur.round().abs().toString();
  final tampon = StringBuffer();
  for (var i = 0; i < entier.length; i++) {
    if (i > 0 && (entier.length - i) % 3 == 0) tampon.write(' ');
    tampon.write(entier[i]);
  }
  final signe = valeur < 0 ? '−' : '';
  return '$signe$tampon ${devise == 'XAF' ? 'FCFA' : devise}';
}
