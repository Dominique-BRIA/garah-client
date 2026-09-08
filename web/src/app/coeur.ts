import { ChangeDetectionStrategy, Component, inject, input, signal } from '@angular/core';
import { Router } from '@angular/router';

import { ServiceFavoris } from '../services/favoris';
import { ServiceSession } from '../services/session';

/**
 * Le cœur d'une liste d'envies.
 *
 * <h2>⚠️ Il ne navigue pas — il est POSÉ sur ce qui navigue</h2>
 *
 * <p>Sur une vignette de catalogue, la carte entière est un lien. Un bouton
 * placé dedans doit donc arrêter l'événement, sinon un clic sur le cœur ouvre
 * la fiche produit : on croit avoir enregistré un article, et on se retrouve
 * ailleurs sans savoir pourquoi.</p>
 *
 * <h2>Sans compte, il mène à la connexion</h2>
 *
 * <p>Et non à rien. Un cœur qui ne réagit pas se clique trois fois avant qu'on
 * renonce ; dire « il faut un compte » est une réponse, l'immobilité n'en est
 * pas une.</p>
 */
@Component({
  selector: 'gb-coeur',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <button type="button" class="coeur" [class.coeur--actif]="favori()"
            (click)="basculer($event)"
            [attr.aria-pressed]="favori()"
            [attr.aria-label]="favori() ? 'Retirer de ma liste' : 'Ajouter à ma liste'"
            [title]="favori() ? 'Retirer de ma liste' : 'Ajouter à ma liste'">
      <svg viewBox="0 0 24 24" aria-hidden="true"
           [attr.fill]="favori() ? 'currentColor' : 'none'">
        <path d="M12 20s-7-4.6-7-9.3A4 4 0 0 1 12 8a4 4 0 0 1 7-2.7c0 4.7-7 14.7-7 14.7Z"
              stroke="currentColor" stroke-width="1.7" stroke-linejoin="round" />
      </svg>
    </button>
  `,
  styles: [
    `
      :host { display: inline-flex; }

      .coeur {
        width: var(--cible-tactile-min);
        height: var(--cible-tactile-min);
        display: inline-flex;
        align-items: center;
        justify-content: center;
        padding: 0;
        border: 1px solid var(--verre-bordure);
        border-radius: 9999px;
        background: var(--verre-fond);
        backdrop-filter: blur(12px);
        -webkit-backdrop-filter: blur(12px);
        color: var(--texte-attenue);
        cursor: pointer;
        transition: color 0.2s ease-in-out, border-color 0.2s ease-in-out;
      }

      svg { width: 20px; height: 20px; }

      .coeur--actif { color: var(--danger); border-color: color-mix(in srgb, var(--danger) 35%, transparent); }

      .coeur:focus-visible { outline: 2px solid var(--primaire); outline-offset: 2px; }

      @media (hover: hover) {
        .coeur:hover { color: var(--danger); border-color: color-mix(in srgb, var(--danger) 45%, transparent); }
      }
    `,
  ],
})
export class Coeur {
  private readonly favoris = inject(ServiceFavoris);
  private readonly session = inject(ServiceSession);
  private readonly routeur = inject(Router);

  readonly produitId = input.required<number>();

  /** Où revenir après la connexion, quand le cœur y mène. */
  readonly retour = input<string | null>(null);

  protected readonly forceur = signal(0);

  protected favori(): boolean {
    // `forceur` n'est pas décoratif : le service tient un Set, et OnPush ne
    // relit pas une méthode sans signal. Le toucher à chaque bascule redonne
    // la main au rendu.
    this.forceur();
    return this.favoris.estFavori(this.produitId());
  }

  protected basculer(evenement: Event): void {
    // ⚠️ Les deux, et dans cet ordre : `preventDefault` empêche le lien
    //    parent de suivre son href, `stopPropagation` empêche un routerLink
    //    posé plus haut de naviguer quand même.
    evenement.preventDefault();
    evenement.stopPropagation();

    if (!this.session.connecte()) {
      this.routeur.navigate(['/connexion'], {
        queryParams: this.retour() ? { suite: this.retour() } : {},
      });
      return;
    }

    this.favoris.basculer(this.produitId());
    this.forceur.update((n) => n + 1);
  }
}
