import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Component, computed, inject, input, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';

import {
  Declinaison,
  FicheVitrine,
  MediaProduit,
  PalierPrix,
  estAchetable,
  montantLisible,
  palierPour,
  palierSuivant,
  plagePalier,
} from '../../modeles/catalogue';
import { PanierLocal } from '../../services/panier-local';
import { ServiceSession } from '../../services/session';
import { Coeur } from '../coeur';

/**
 * La fiche produit.
 *
 * <h2>La grille de paliers est AVANT le bouton d'achat</h2>
 *
 * <p>🎯 C'est le cœur de cet écran, et l'alignement sur la « ladder pricing »
 * d'Alibaba : le prix unitaire baisse par tranches, et le palier applicable
 * est mis en évidence.</p>
 *
 * <p>Sans cette grille, le prix change entre la fiche et le panier — et ça
 * ressemble à une arnaque. C'est pour l'afficher que
 * {@code GET /produits/{slug}/vitrine} existe : la fiche publique ordinaire ne
 * porte aucun prix.</p>
 *
 * <h2>Ce que l'écran ne promet pas</h2>
 *
 * <p>⚠️ Les paliers affichés sont ceux <b>du jour</b>. Le tarif qui compte est
 * figé par le serveur au passage de commande (D-10) : cet écran informe, il
 * n'engage pas. Présenter son propre calcul comme un engagement mentirait le
 * jour où un tarif change entre l'affichage et le paiement.</p>
 */
@Component({
  selector: 'gb-produit',
  imports: [RouterLink, Coeur],
  templateUrl: './produit.html',
  styleUrl: './produit.scss',
})
export class Produit {
  private readonly http = inject(HttpClient);
  private readonly router = inject(Router);
  private readonly panier = inject(PanierLocal);
  private readonly session = inject(ServiceSession);

  /** Lié depuis la route par `withComponentInputBinding()`. */
  readonly slug = input.required<string>();

  protected readonly fiche = signal<FicheVitrine | null>(null);
  protected readonly chargement = signal(true);
  protected readonly erreur = signal<string | null>(null);

  protected readonly declinaisonId = signal<number | null>(null);
  protected readonly mediaId = signal<number | null>(null);
  /** Le lien vient d'être copié : le dire, sinon le clic n'a rien fait de visible. */
  protected readonly lienCopie = signal(false);
  protected readonly quantite = signal(1);
  protected readonly ajoute = signal(false);
  protected readonly contact = signal(false);

  /** La déclinaison choisie, ou la première proposée. */
  protected readonly declinaison = computed<Declinaison | null>(() => {
    const f = this.fiche();
    if (!f || f.declinaisons.length === 0) {
      return null;
    }
    const choisie = f.declinaisons.find((d) => d.id === this.declinaisonId());
    return choisie ?? f.declinaisons[0];
  });

  /** Le palier qui s'applique à la quantité courante. */
  protected readonly palierActif = computed<PalierPrix | null>(() => {
    const d = this.declinaison();
    return d ? palierPour(d.paliers, this.quantite()) : null;
  });

  /**
   * Ce qu'on gagnerait à monter d'un palier.
   *
   * <p>N'apparaît que si le palier suivant existe <b>et</b> que le stock
   * suit : promettre un tarif indisponible est pire que se taire.</p>
   */
  protected readonly prochainPalier = computed<PalierPrix | null>(() => {
    const d = this.declinaison();
    return d ? palierSuivant(d.paliers, this.quantite(), d.disponible) : null;
  });

  /**
   * La quantité la plus haute qui ait un prix.
   *
   * <h2>🎯 Le sous-total tombait à « 0 FCFA »</h2>
   *
   * <p>Le sélecteur plafonnait au STOCK. Sur un article à 30 en réserve dont
   * les paliers s'arrêtaient à 10, on pouvait donc demander 11 — une quantité
   * qui ne tombe dans aucun palier. {@link palierPour} rendait alors
   * {@code null}, et le sous-total affichait <b>0 FCFA</b>.</p>
   *
   * <p>⚠️ Zéro n'est pas une valeur manquante à l'écran : c'est une PROMESSE
   * DE GRATUITÉ. Et le bouton « Ajouter au panier » ne faisait rien du tout,
   * sans le moindre message — on cliquait, et l'on cherchait la panne.</p>
   *
   * <p>⚠️ Un palier sans maximum signifie « et au-delà » : dès qu'il en existe
   * un, plus rien ne borne le tarif. C'est la forme NORMALE d'une grille bien
   * saisie, et celle-ci ne déclenche donc aucun plafond.</p>
   */
  protected readonly plafondTarifaire = computed(() => {
    const paliers = this.declinaison()?.paliers ?? [];
    if (paliers.length === 0) {
      return 0;
    }
    if (paliers.some((p) => p.quantiteMax === null)) {
      return Number.POSITIVE_INFINITY;
    }
    return Math.max(...paliers.map((p) => p.quantiteMax ?? 0));
  });

  /** Le plafond réellement appliqué : le premier des deux qui mord. */
  protected readonly plafond = computed(() => {
    const d = this.declinaison();
    if (!d) {
      return 1;
    }
    return Math.min(d.disponible, this.plafondTarifaire());
  });

  /**
   * Vrai quand c'est la GRILLE qui borne, et non le stock.
   *
   * <p>La distinction compte pour qui lit : « il n'en reste que 10 » et « au
   * delà de 10 le prix n'est pas fixé » n'appellent pas le même geste. Le
   * second se règle en écrivant au marchand, et l'écran le propose.</p>
   */
  protected readonly borneParLeTarif = computed(() => {
    const d = this.declinaison();
    return !!d && this.plafondTarifaire() < d.disponible;
  });

  protected readonly sousTotal = computed(() => {
    const palier = this.palierActif();
    return palier ? palier.prixUnitaire * this.quantite() : 0;
  });

  /**
   * La quantité minimale, affichée seulement si elle dépasse 1.
   *
   * <p>C'est le MOQ d'Alibaba. Chez GARAH il vaut presque toujours 1 :
   * l'afficher partout serait du bruit sur toutes les fiches.</p>
   */
  protected readonly minimumAffichable = computed(() => {
    const d = this.declinaison();
    return d && d.quantiteMinimale > 1 ? d.quantiteMinimale : null;
  });

  /**
   * Les photos, la principale en tête.
   *
   * <p>🎯 La fiche en renvoie plusieurs depuis toujours ; l'écran n'en montrait
   * qu'une. Sur un téléphone on tolère une seule image ; sur un écran large la
   * place est là — et une seule photo d'un article qu'on ne peut ni toucher ni
   * essayer, c'est une raison de ne pas acheter.</p>
   */
  protected readonly photos = computed<readonly MediaProduit[]>(() => {
    const medias = this.fiche()?.medias ?? [];
    return [...medias].sort(
      (a, b) => Number(b.principal) - Number(a.principal) || a.ordre - b.ordre,
    );
  });

  /** La couverture : celle qui part au panier, quoi qu'on regarde à l'écran. */
  protected readonly photoPrincipale = computed(() => this.photos()[0]?.url ?? null);

  /** Celle qu'on regarde en ce moment. */
  protected readonly photoAffichee = computed(() => {
    const choisie = this.photos().find((m) => m.id === this.mediaId());
    return choisie?.url ?? this.photoPrincipale();
  });

  /**
   * La mention de TVA, seulement s'il y en a une.
   *
   * <p>Le taux ne regarde pas le client : ce qu'il veut savoir, c'est si le
   * prix affiché est celui qu'il paiera.</p>
   */
  protected readonly tvaIncluse = computed(() => (this.fiche()?.tauxTva ?? 0) > 0);

  constructor() {
    // `input.required` n'est pas lisible dans le constructeur : on charge au
    // premier rendu, quand la valeur est posée.
    queueMicrotask(() => this.charger());
  }

  protected charger(): void {
    this.chargement.set(true);
    this.erreur.set(null);

    this.http
      .get<FicheVitrine>(`/api/produits/${encodeURIComponent(this.slug())}/vitrine`)
      .subscribe({
        next: (f) => {
          this.fiche.set(f);
          this.mediaId.set(null);
          this.chargement.set(false);

          // On ouvre sur une déclinaison ACHETABLE si elle existe : ouvrir sur
          // une taille épuisée ferait croire que le produit ne l'est plus.
          const premiere = f.declinaisons.find(estAchetable) ?? f.declinaisons[0];
          if (premiere) {
            this.declinaisonId.set(premiere.id);
            this.quantite.set(Math.max(1, premiere.quantiteMinimale));
          }

          this.compterLaVue();
        },
        error: (e: unknown) => {
          this.chargement.set(false);
          this.erreur.set(message(e));
        },
      });
  }

  /**
   * Enregistre la consultation.
   *
   * <p>⚠️ <b>Ne doit jamais bloquer l'affichage.</b> Une statistique perdue
   * est regrettable, une fiche produit en erreur est un client perdu — le
   * serveur avale déjà ses propres échecs, on fait pareil ici.</p>
   */
  private compterLaVue(): void {
    const id = this.fiche()?.id;
    if (!id) {
      return;
    }
    this.http.post(`/api/produits/${id}/vues`, { source: 'FICHE' }).subscribe({
      error: () => {
        /* volontairement ignoré */
      },
    });
  }

  // -------------------------------------------------------------------------

  protected choisir(d: Declinaison): void {
    if (!estAchetable(d)) {
      return;
    }
    this.declinaisonId.set(d.id);
    // La quantité repart au minimum de CETTE déclinaison : la garder pourrait
    // dépasser un stock plus faible, et le bouton se désactiverait sans que la
    // raison soit visible.
    this.quantite.set(Math.max(1, d.quantiteMinimale));
    this.ajoute.set(false);
  }

  protected changerQuantite(delta: number): void {
    const d = this.declinaison();
    if (!d) {
      return;
    }
    const minimum = Math.max(1, d.quantiteMinimale);
    const suivante = this.quantite() + delta;

    // ⚠️ On borne par le PLAFOND et non par le stock : au-dela du dernier
    //    palier il n existe aucun prix, et laisser monter la quantite menait
    //    tout droit au sous-total a zero.
    this.quantite.set(Math.min(Math.max(suivante, minimum), Math.max(minimum, this.plafond())));
    this.ajoute.set(false);
  }

  protected ajouterAuPanier(): void {
    const f = this.fiche();
    const d = this.declinaison();
    const palier = this.palierActif();

    if (!f || !d || !palier) {
      return;
    }

    this.panier.ajouter({
      varianteId: d.id,
      quantite: this.quantite(),
      nomProduit: f.nom,
      libelleDeclinaison: d.libelle,
      urlPhoto: this.photoPrincipale(),
      // Indicatif : le serveur recalcule au bon palier, et fige à la commande.
      prixIndicatif: palier.prixUnitaire,
    });

    this.ajoute.set(true);
  }

  protected choisirPhoto(m: MediaProduit): void {
    this.mediaId.set(m.id);
  }

  /**
   * Partager la fiche.
   *
   * <p>🎯 Un article se montre à quelqu'un avant de s'acheter. Sans ce bouton,
   * il faut recopier la barre d'adresse — ce que personne ne fait depuis un
   * téléphone.</p>
   *
   * <p>⚠️ {@code navigator.share} n'existe pas sur tous les navigateurs de
   * bureau, et le presse-papier est refusé hors contexte sécurisé. Les deux
   * échouent en silence : d'où le repli, puis le repli du repli.</p>
   */
  protected partager(): void {
    const f = this.fiche();
    if (!f) {
      return;
    }
    const url = location.href;

    if (navigator.share) {
      // Le rejet est la NORME ici : c'est l'utilisateur qui referme la feuille
      // de partage. On ne le traite donc pas comme une panne.
      navigator.share({ title: f.nom, url }).catch(() => this.copier(url));
      return;
    }
    this.copier(url);
  }

  private copier(url: string): void {
    navigator.clipboard
      ?.writeText(url)
      .then(() => {
        this.lienCopie.set(true);
        setTimeout(() => this.lienCopie.set(false), 2500);
      })
      .catch(() => {
        /* rien de plus à proposer : l'URL reste dans la barre d'adresse */
      });
  }

  /**
   * Ouvre une question sur CET article.
   *
   * <h2>🎯 Ce bouton s'appelait « Négocier »</h2>
   *
   * <p>Le prix affiché est <b>ferme</b>. Il ne se discute pas article par
   * article — sauf cas rare, qui se traite alors dans le fil, à la main. Un
   * bouton « Négocier » sur chaque fiche promettait l'inverse : il installait
   * le marchandage comme le mode normal d'achat, et mettait la maison dans
   * une posture qu'elle ne tient pas.</p>
   *
   * <p>Ce qui manquait vraiment était plus simple : <b>poser une question</b>.
   * Les dimensions réelles, la matière, le délai, la garantie — tout ce qui
   * décide un achat et qu'une fiche ne dira jamais entièrement.</p>
   *
   * <h2>Ce que le message porte</h2>
   *
   * <p>Le sujet et le premier message nomment l'article, et la quantité quand
   * elle dépasse une pièce : le conseiller qui prend la main sait de quoi on
   * parle sans rien demander. On n'écrit pas le prix — il est sur la fiche,
   * et le recopier dans un fil en ferait une valeur qui vieillit.</p>
   *
   * <p>⚠️ Sans compte, on passe par la connexion avec l'adresse de retour :
   * écrire exige d'être identifié, mais renvoyer sans retour ferait perdre
   * l'article qu'on regardait.</p>
   */
  protected contacter(): void {
    const f = this.fiche();
    const d = this.declinaison();
    if (!f || !d || this.contact()) {
      return;
    }

    if (!this.session.connecte()) {
      this.router.navigate(['/connexion'], {
        queryParams: { suite: `/produit/${this.slug()}` },
      });
      return;
    }

    this.contact.set(true);

    const article = f.declinaisons.length > 1 ? `${f.nom} — ${d.libelle}` : f.nom;

    this.http
      .post<{ id: number }>('/api/conversations', {
        sujet: `Question : ${article}`.slice(0, 200),
        premierMessage:
          `Bonjour, je voudrais en savoir plus sur « ${article} »`
          + (this.quantite() > 1 ? ` (${this.quantite()} pièces).` : '.'),
      })
      .subscribe({
        next: (c) => {
          this.contact.set(false);
          this.router.navigate(['/mes-discussions', c.id]);
        },
        error: () => {
          this.contact.set(false);
          // On ne bloque pas sur cet écran : la liste des discussions
          // permettra d'en ouvrir une à la main.
          this.router.navigate(['/mes-discussions']);
        },
      });
  }

  // -------------------------------------------------------------------------

  protected achetable(d: Declinaison): boolean {
    return estAchetable(d);
  }

  protected plage(p: PalierPrix): string {
    return plagePalier(p);
  }

  protected estPalierActif(p: PalierPrix): boolean {
    return this.palierActif()?.quantiteMin === p.quantiteMin;
  }

  protected montant(valeur: number | null): string {
    return montantLisible(valeur);
  }

  /** Combien d'unités manquent pour atteindre le palier suivant. */
  protected manquePour(p: PalierPrix): number {
    return p.quantiteMin - this.quantite();
  }
}

function message(e: unknown): string {
  if (e instanceof HttpErrorResponse) {
    if (e.status === 0) {
      return 'Pas de connexion. Réessayez dans un instant.';
    }
    if (e.status === 404) {
      // ⚠️ Un produit dépublié rend 404 sur cette route. Le dire comme une
      //    absence, pas comme une panne : le lien vient peut-être d'un partage
      //    vieux de plusieurs semaines.
      return 'Cet article n’est plus proposé à la vente.';
    }
  }
  return 'Cette fiche n’a pas pu être chargée.';
}
