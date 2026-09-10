import { ChangeDetectionStrategy, Component } from '@angular/core';
import { RouterLink } from '@angular/router';

/**
 * Le retour vers « Mon compte », en tête de chaque écran de l'espace personnel.
 *
 * <h2>🎯 Il remplace la rangée de six pastilles</h2>
 *
 * <p>Chaque écran du compte — commandes, liste, discussions, retours,
 * réclamations, profil — commençait par la même rangée de six pastilles. Elle
 * reproduisait sur chaque page ce que l'écran « Mon compte » montre
 * désormais une fois, et repoussait le contenu vers le bas.</p>
 *
 * <p>Un seul lien la remplace : revenir aux portes. C'est la flèche de retour
 * de l'application Android, écrite pour le web — la même navigation sur les
 * deux supports.</p>
 */
@Component({
  selector: 'gb-retour-compte',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [RouterLink],
  template: `
    <a routerLink="/compte" class="retour">
      <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
        <path d="m15 6-6 6 6 6" stroke="currentColor" stroke-width="1.8"
              stroke-linecap="round" stroke-linejoin="round" />
      </svg>
      Mon compte
    </a>
  `,
  styles: `
    :host { display: block; padding: 1rem 1.25rem 0; }

    .retour {
      min-height: var(--cible-tactile-min);
      display: inline-flex;
      align-items: center;
      gap: 0.3rem;
      font-size: 0.83rem;
      font-weight: 600;
      color: var(--texte-attenue);
      text-decoration: none;

      svg { width: 16px; height: 16px; }
      &:focus-visible { outline: 2px solid var(--primaire); outline-offset: 2px; }
    }

    @media (hover: hover) {
      .retour:hover { color: var(--texte); }
    }

    @media (min-width: 900px) {
      :host { padding-left: 0; padding-right: 0; }
    }
  `,
})
export class RetourCompte {}
