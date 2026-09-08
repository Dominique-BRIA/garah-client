import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Component, computed, inject, input, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';

import {
  Declinaison,
  FicheVitrine,
  PalierPrix,
  estAchetable,
  montantLisible,
  palierPour,
  palierSuivant,
  plagePalier,
} from '../../modeles/catalogue';
import { PanierLocal } from '../../services/panier-local';

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
  imports: [RouterLink],
  templateUrl: './produit.html',
  styleUrl: './produit.scss',
})
export class Produit {
  private readonly http = inject(HttpClient);
  private readonly router = inject(Router);
  private readonly panier = inject(PanierLocal);

  /** Lié depuis la route par `withComponentInputBinding()`. */
  readonly slug = input.required<string>();

  protected readonly fiche = signal<FicheVitrine | null>(null);
  protected readonly chargement = signal(true);
  protected readonly erreur = signal<string | null>(null);

  protected readonly declinaisonId = signal<number | null>(null);
  protected readonly quantite = signal(1);
  protected readonly ajoute = signal(false);

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

  protected readonly photoPrincipale = computed(
    () => this.fiche()?.medias.find((m) => m.principal)?.url ?? this.fiche()?.medias[0]?.url ?? null,
  );

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

    this.quantite.set(Math.min(Math.max(suivante, minimum), Math.max(minimum, d.disponible)));
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

  protected negocier(): void {
    // La négociation vit dans une conversation, qui exige un compte.
    this.router.navigate(['/connexion'], {
      queryParams: { suite: `/produit/${this.slug()}` },
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
