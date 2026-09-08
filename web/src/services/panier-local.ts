import { Injectable, computed, signal } from '@angular/core';

/** Une ligne telle que le navigateur la garde. */
export interface LigneLocale {
  readonly varianteId: number;
  readonly quantite: number;
  /** Recopiés pour AFFICHER le panier hors connexion — jamais pour calculer. */
  readonly nomProduit: string;
  readonly libelleDeclinaison: string;
  readonly urlPhoto: string | null;
  readonly prixIndicatif: number;
}

const CLE = 'garah.panier';
const MAX_LIGNES = 100;

/**
 * Le panier d'un visiteur non connecté.
 *
 * <h2>Pourquoi il existe</h2>
 *
 * <p>La vitrine est ouverte, le paiement non (D-07). Forcer la connexion au
 * premier « Ajouter » serait franc, mais ferait fuir le visiteur qui découvre
 * — et sur cet axe, le premier contact vient souvent d'un lien partagé, sans
 * compte.</p>
 *
 * <h2>⚠️ CE PANIER N'EST JAMAIS LA VÉRITÉ</h2>
 *
 * <p>Il ne connaît ni le stock, ni le prix courant, ni ce que le client a mis
 * de côté depuis un autre appareil. {@link prixIndicatif} sert à afficher un
 * total approximatif hors connexion, <b>jamais</b> à engager quoi que ce
 * soit : le serveur recalcule tout, et fige les montants au passage de
 * commande.</p>
 *
 * <p>À la connexion, {@code POST /api/panier/fusion} reprend ces lignes et
 * rend les <b>écarts</b> — article retiré, quantité déjà plus grande
 * ailleurs. C'est l'écran qui les annonce.</p>
 */
@Injectable({ providedIn: 'root' })
export class PanierLocal {
  private readonly lignesInternes = signal<readonly LigneLocale[]>(lire());

  readonly lignes = this.lignesInternes.asReadonly();

  readonly nombreArticles = computed(() =>
    this.lignesInternes().reduce((total, l) => total + l.quantite, 0),
  );

  /**
   * Le total <b>indicatif</b>.
   *
   * <p>⚠️ Il ignore les paliers de quantité et les frais d'acheminement : le
   * serveur, lui, applique le bon palier et ajoute les frais du point choisi.
   * L'écran doit donc le présenter comme une estimation, jamais comme un prix
   * à payer.</p>
   */
  readonly totalIndicatif = computed(() =>
    this.lignesInternes().reduce((total, l) => total + l.prixIndicatif * l.quantite, 0),
  );

  /**
   * Ajoute une quantité, ou crée la ligne.
   *
   * <p>Additif ici, contrairement à la fusion : le visiteur voit son panier,
   * il sait ce qu'il ajoute.</p>
   */
  ajouter(ligne: LigneLocale): void {
    this.lignesInternes.update((lignes) => {
      const existante = lignes.find((l) => l.varianteId === ligne.varianteId);

      if (existante) {
        return lignes.map((l) =>
          l.varianteId === ligne.varianteId ? { ...l, quantite: l.quantite + ligne.quantite } : l,
        );
      }

      // Le plafond protège d'un stockage local gonflé : le serveur refuse
      // au-delà de cent lignes, autant ne pas construire un panier qu'il
      // rejettera.
      if (lignes.length >= MAX_LIGNES) {
        return lignes;
      }
      return [...lignes, ligne];
    });
    this.enregistrer();
  }

  /** Fixe la quantité. Zéro retire la ligne — le geste attendu. */
  definirQuantite(varianteId: number, quantite: number): void {
    this.lignesInternes.update((lignes) =>
      quantite <= 0
        ? lignes.filter((l) => l.varianteId !== varianteId)
        : lignes.map((l) => (l.varianteId === varianteId ? { ...l, quantite } : l)),
    );
    this.enregistrer();
  }

  retirer(varianteId: number): void {
    this.lignesInternes.update((lignes) => lignes.filter((l) => l.varianteId !== varianteId));
    this.enregistrer();
  }

  /**
   * Vide le panier.
   *
   * <p>⚠️ Appelé après une fusion réussie <b>et</b> à la déconnexion. Le
   * second cas n'est pas du zèle : sur un poste partagé, le panier d'un
   * visiteur ne doit pas accueillir le suivant.</p>
   */
  vider(): void {
    this.lignesInternes.set([]);
    this.enregistrer();
  }

  /** Ce qu'on envoie à la fusion : le serveur n'a besoin que de deux champs. */
  pourFusion(): { varianteId: number; quantite: number }[] {
    return this.lignesInternes().map((l) => ({ varianteId: l.varianteId, quantite: l.quantite }));
  }

  private enregistrer(): void {
    try {
      localStorage.setItem(CLE, JSON.stringify(this.lignesInternes()));
    } catch {
      // Navigation privée, quota plein, stockage bloqué : le panier reste en
      // mémoire pour cette visite. Faire échouer l'ajout serait pire — le
      // visiteur ne comprendrait pas pourquoi le bouton ne fait rien.
    }
  }
}

/**
 * Relit le panier au démarrage.
 *
 * <p>⚠️ Tout ce qui vient de {@code localStorage} est <b>suspect</b> : une
 * version précédente de l'application, une main curieuse, un quota tronqué. On
 * valide chaque ligne plutôt que de faire confiance à la forme — une quantité
 * négative ou un identifiant absent produirait un panier que le serveur
 * refuserait, sans que l'écran sache pourquoi.</p>
 */
function lire(): readonly LigneLocale[] {
  try {
    const brut = localStorage.getItem(CLE);
    if (!brut) {
      return [];
    }

    const lu: unknown = JSON.parse(brut);
    if (!Array.isArray(lu)) {
      return [];
    }

    return lu.filter(estLigneValide).slice(0, MAX_LIGNES);
  } catch {
    return [];
  }
}

function estLigneValide(valeur: unknown): valeur is LigneLocale {
  if (typeof valeur !== 'object' || valeur === null) {
    return false;
  }
  const l = valeur as Record<string, unknown>;
  return (
    typeof l['varianteId'] === 'number' &&
    Number.isFinite(l['varianteId']) &&
    typeof l['quantite'] === 'number' &&
    Number.isInteger(l['quantite']) &&
    l['quantite'] > 0 &&
    typeof l['nomProduit'] === 'string'
  );
}
