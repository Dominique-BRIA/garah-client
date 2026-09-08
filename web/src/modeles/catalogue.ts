// =============================================================================
// Le catalogue, vu de la vitrine
// =============================================================================
// Ces types recopient les records du serveur. La copie est ASSUMEE : engendrer
// depuis Spring serait un chantier a lui seul pour une poignee de records, et
// une divergence se voit au premier appel — le champ manquant vaut `undefined`
// et l'ecran l'affiche vide.
// =============================================================================

/** Une page renvoyee par Spring Data. */
export interface Page<T> {
  readonly content: T[];
  readonly page: {
    readonly size: number;
    readonly number: number;
    readonly totalElements: number;
    readonly totalPages: number;
  };
}

/** Un produit dans une liste. `GET /api/produits` */
export interface ResumeProduit {
  readonly id: number;
  readonly reference: string;
  readonly nom: string;
  readonly slug: string;
  readonly statut: string;
  readonly clePhotoPrincipale: string | null;
  readonly urlPhotoPrincipale: string | null;
  readonly marchandNom: string | null;
  readonly categorieNom: string | null;
  /** Le plus petit prix, tous paliers et declinaisons confondus. */
  readonly prixMin: number | null;
  readonly devise: string;
  /** Somme sur toutes les declinaisons : une taille epuisee n'epuise pas le produit. */
  readonly quantiteDisponible: number;
}

/**
 * Un palier de prix.
 *
 * 🎯 C'est la « ladder pricing » d'Alibaba : le prix unitaire baisse par
 * tranches de quantite.
 *
 * @param quantiteMax nul signifie « et au-dela ».
 */
export interface PalierPrix {
  readonly quantiteMin: number;
  readonly quantiteMax: number | null;
  readonly prixUnitaire: number;
}

/**
 * Une declinaison achetable.
 *
 * `GET /api/produits/{slug}/vitrine`
 */
export interface Declinaison {
  readonly id: number;
  readonly sku: string;
  readonly libelle: string;
  readonly parDefaut: boolean;
  /** Vide = aucun tarif parametre. La declinaison n'est alors PAS achetable. */
  readonly paliers: readonly PalierPrix[];
  readonly disponible: number;
  /**
   * Le plus petit palier de la grille — le MOQ d'Alibaba.
   *
   * Vaut presque toujours 1 chez GARAH : l'ecran ne l'affiche QUE s'il
   * depasse 1, sinon c'est du bruit sur toutes les fiches.
   */
  readonly quantiteMinimale: number;
}

export interface MediaProduit {
  readonly id: number;
  readonly type: string;
  readonly url: string;
  readonly principal: boolean;
  readonly ordre: number;
}

/**
 * La fiche telle que la vitrine l'affiche.
 *
 * ⚠️ Distincte de la fiche d'administration, et pas par confort : celle-ci
 * porte la GRILLE DE PRIX et la DISPONIBILITE, sans quoi le prix change entre
 * la fiche et le panier — et ca ressemble a une arnaque.
 */
export interface FicheVitrine {
  readonly id: number;
  readonly nom: string;
  readonly slug: string;
  readonly description: string | null;
  readonly tauxTva: number;
  readonly marchandId: number;
  /** Nul si le marchand a disparu : l'ecran ecrit « vendeur inconnu ». */
  readonly marchandNom: string | null;
  readonly categorie: { readonly id: number; readonly nom: string; readonly slug: string };
  readonly declinaisons: readonly Declinaison[];
  readonly medias: readonly MediaProduit[];
}

export interface Categorie {
  readonly id: number;
  readonly nom: string;
  readonly slug: string;
  readonly parentId: number | null;
}

// -----------------------------------------------------------------------------

/**
 * Achetable : il faut UN PRIX **et** DU STOCK.
 *
 * ⚠️ Les deux, pas seulement le stock. Une declinaison en rayon mais sans
 * tarif se laisserait mettre au panier et echouerait au paiement — au pire
 * moment, quand le client a deja sorti son telephone.
 *
 * Le serveur applique la meme regle ; celle-ci ne sert qu'a ne pas proposer un
 * bouton qui echouera.
 */
export function estAchetable(d: Declinaison): boolean {
  return d.paliers.length > 0 && d.disponible > 0;
}

/**
 * Le palier qui s'applique a cette quantite.
 *
 * Nul si aucun ne la couvre — en dessous du minimum, par exemple.
 */
export function palierPour(paliers: readonly PalierPrix[], quantite: number): PalierPrix | null {
  return (
    paliers.find(
      (p) => quantite >= p.quantiteMin && (p.quantiteMax === null || quantite <= p.quantiteMax),
    ) ?? null
  );
}

/**
 * Le palier SUIVANT, celui qu'on gagnerait a atteindre.
 *
 * Nul s'il n'y en a pas, ou si le stock ne suit pas : promettre un tarif
 * indisponible est pire que se taire.
 */
export function palierSuivant(
  paliers: readonly PalierPrix[],
  quantite: number,
  disponible: number,
): PalierPrix | null {
  const suivant = paliers.find((p) => p.quantiteMin > quantite);
  if (!suivant || suivant.quantiteMin > disponible) {
    return null;
  }
  return suivant;
}

/** « 6 – 11 », ou « 48 et + » pour le dernier palier. */
export function plagePalier(p: PalierPrix): string {
  return p.quantiteMax === null ? `${p.quantiteMin} et +` : `${p.quantiteMin} – ${p.quantiteMax}`;
}

/**
 * Un montant lisible : « 106 000 FCFA ».
 *
 * L'espace insecable etroit separe les milliers sans que le nombre se coupe en
 * fin de ligne.
 */
export function montantLisible(valeur: number | null, devise = 'XAF'): string {
  if (valeur === null || valeur === undefined) {
    return '—';
  }
  const nombre = new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 0 }).format(valeur);
  return `${nombre} ${devise === 'XAF' ? 'FCFA' : devise}`;
}
