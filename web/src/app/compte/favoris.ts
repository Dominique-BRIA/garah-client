import { HttpClient } from '@angular/common/http';
import { Component, effect, inject, signal, untracked } from '@angular/core';
import { RouterLink } from '@angular/router';

import { ResumeProduit, montantLisible } from '../../modeles/catalogue';
import { ServiceFavoris } from '../../services/favoris';
import { Coeur } from '../coeur';
import { RetourCompte } from './retour-compte';

/**
 * Ma liste d'envies.
 *
 * <h2>Deux appels, jamais un par ligne</h2>
 *
 * <p>Le service tient des <b>identifiants</b> — la mesure ne connaît pas le
 * catalogue, et ne doit pas le connaître. Les vignettes viennent d'un second
 * appel, {@code /produits/par-ids}, qui les rend toutes d'un coup et
 * <b>dans l'ordre demandé</b>.</p>
 *
 * <h2>⚠️ On peut recevoir moins d'articles qu'on n'en a mis</h2>
 *
 * <p>Un produit dépublié depuis disparaît de la réponse. C'est voulu : le
 * garder afficherait dans la boutique un article qu'on ne peut plus acheter.
 * L'écran le <b>dit</b> plutôt que de laisser croire à une liste tronquée par
 * accident — un compte à deux chiffres qui ne tombe pas juste inquiète plus
 * qu'une phrase.</p>
 */
@Component({
  selector: 'gb-favoris',
  imports: [RouterLink, Coeur, RetourCompte],
  template: `
    <gb-retour-compte />

    <header class="entete">
      <h1>Ma liste</h1>
      <p class="entete__aide">Les articles que vous avez mis de côté.</p>
    </header>


    @if (chargement()) {
      <div class="gb-etat"><p>Chargement…</p></div>
    } @else if (favoris.nombre() === 0) {
      <div class="gb-etat">
        <p>Votre liste est vide.</p>
        <p class="gb-attenue">
          Le cœur sur un article l’ajoute ici, et vous le retrouvez d’un
          appareil à l’autre.
        </p>
        <a routerLink="/catalogue" class="gb-btn gb-btn--secondaire">Parcourir le catalogue</a>
      </div>
    } @else {
      @if (disparus() > 0) {
        <p class="disparus">
          {{ disparus() }} article(s) de votre liste ne sont plus proposés à la
          vente.
        </p>
      }

      <div class="grille">
        @for (p of produits(); track p.id) {
          <a class="carte" [routerLink]="['/produit', p.slug]">
            <gb-coeur class="carte__coeur" [produitId]="p.id" />
            <div class="carte__image">
              @if (p.urlPhotoPrincipale) {
                <img [src]="p.urlPhotoPrincipale" [alt]="p.nom" loading="lazy" decoding="async" />
              } @else {
                <svg viewBox="0 0 24 24" fill="none" aria-hidden="true" class="carte__silhouette">
                  <path d="M8 4 5 6v14h14V6l-3-2-4 2-4-2Z" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round" />
                </svg>
              }
            </div>
            <div class="carte__corps">
              @if (p.categorieNom) { <p class="carte__categorie">{{ p.categorieNom }}</p> }
              <p class="carte__nom">{{ p.nom }}</p>
              @if (p.marchandNom) { <p class="carte__vendeur">{{ p.marchandNom }}</p> }
              <p class="carte__prix">
                <span class="carte__des gb-attenue">dès</span> {{ montant(p.prixMin, p.devise) }}
              </p>
              @if (p.quantiteDisponible === 0) {
                <span class="gb-etiquette gb-etiquette--neutre carte__epuise">Épuisé</span>
              } @else if (p.quantiteDisponible <= 5) {
                <span class="gb-etiquette gb-etiquette--alerte carte__epuise">
                  Plus que {{ p.quantiteDisponible }}
                </span>
              }
            </div>
          </a>
        }
      </div>
    }
  `,
  styles: `
    .entete { padding: 1.5rem 1.25rem 0.25rem; }
    .entete h1 { margin: 0; font-size: 1.3rem; font-weight: 700; }
    .entete__aide { margin: 0.25rem 0 0; font-size: 0.82rem; color: var(--texte-attenue); }

    .disparus {
      margin: 1rem 1.25rem 0;
      padding: 0.7rem 0.9rem;
      border-radius: var(--rayon-petit);
      background: var(--surface-douce);
      font-size: 0.8rem;
      color: var(--texte-attenue);
      line-height: 1.5;
    }

    .grille {
      padding: 1.25rem;
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 0.85rem;
    }

    .carte {
      position: relative;
      display: flex;
      flex-direction: column;
      overflow: hidden;
      border: 1px solid var(--verre-bordure);
      border-radius: var(--rayon-moyen);
      background: var(--verre-fond);
      color: inherit;
      text-decoration: none;
    }

    .carte__coeur { position: absolute; top: 0.35rem; right: 0.35rem; z-index: 2; }

    .carte__image {
      aspect-ratio: 1;
      display: flex;
      align-items: center;
      justify-content: center;
      background: color-mix(in srgb, var(--primaire) 6%, var(--surface-douce));
      color: color-mix(in srgb, var(--primaire) 40%, transparent);

      img { width: 100%; height: 100%; object-fit: cover; }
    }

    .carte__silhouette { width: 38px; height: 38px; }

    .carte__corps {
      padding: 0.7rem 0.75rem 0.85rem;
      display: flex;
      flex-direction: column;
      gap: 0.25rem;
      align-items: flex-start;
    }

    .carte__categorie {
      margin: 0;
      font-size: 0.62rem;
      font-weight: 700;
      letter-spacing: 0.06em;
      text-transform: uppercase;
      color: var(--texte-attenue);
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    .carte__nom {
      margin: 0;
      font-size: 0.83rem;
      font-weight: 600;
      line-height: 1.35;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      line-clamp: 2;
      -webkit-box-orient: vertical;
      overflow: hidden;
    }

    .carte__vendeur { margin: 0; font-size: 0.7rem; color: var(--texte-attenue); }
    .carte__prix { margin: 0.15rem 0 0; font-size: 0.92rem; font-weight: 700; font-variant-numeric: tabular-nums; }
    .carte__des { font-size: 0.7rem; font-weight: 500; }
    .carte__epuise { margin-top: 0.3rem; }

    @media (min-width: 900px) {
      .entete { padding-left: 0; padding-right: 0; }
      .disparus { margin-left: 0; margin-right: 0; }
      .grille { padding-left: 0; padding-right: 0; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 1.25rem; }
    }

    @media (min-width: 640px) and (max-width: 899px) {
      .grille { grid-template-columns: repeat(3, minmax(0, 1fr)); }
    }
  `,
})
export class Favoris {
  private readonly http = inject(HttpClient);
  protected readonly favoris = inject(ServiceFavoris);

  protected readonly produits = signal<readonly ResumeProduit[]>([]);
  protected readonly chargement = signal(true);

  /** Combien d'articles mis de côté ne sont plus en vente. */
  protected readonly disparus = signal(0);

  constructor() {
    // La liste du service peut arriver après le premier rendu : un effet suit
    // ses changements, là où un chargement au constructeur n'aurait vu qu'un
    // ensemble vide.
    effect(() => {
      const ids = this.favoris.liste();
      untracked(() => this.chargerLesVignettes(ids));
    });
  }

  private chargerLesVignettes(ids: readonly number[]): void {
    if (ids.length === 0) {
      this.produits.set([]);
      this.disparus.set(0);
      this.chargement.set(false);
      return;
    }

    this.http.get<ResumeProduit[]>(`/api/produits/par-ids?ids=${ids.join(',')}`).subscribe({
      next: (p) => {
        this.produits.set(p);
        this.disparus.set(ids.length - p.length);
        this.chargement.set(false);
      },
      error: () => {
        this.produits.set([]);
        this.disparus.set(0);
        this.chargement.set(false);
      },
    });
  }

  protected montant(valeur: number | null, devise: string): string {
    return montantLisible(valeur, devise);
  }
}
