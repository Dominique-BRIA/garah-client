import { Component, inject } from '@angular/core';
import { RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';

import { PanierLocal } from '../services/panier-local';

/**
 * La coque de la boutique.
 *
 * <p>⚠️ Elle ne porte <b>aucun garde</b>, contrairement à celle du
 * back-office. La vitrine est ouverte : le garde se pose écran par écran, sur
 * les quatre qui touchent au compte.</p>
 *
 * <p>La barre du bas est la navigation d'une application mobile — quatre
 * destinations, jamais plus. Une cinquième pousserait à un menu « … » que
 * personne n'ouvre.</p>
 */
@Component({
  selector: 'gb-racine',
  imports: [RouterOutlet, RouterLink, RouterLinkActive],
  template: `
    <div class="gb-page">
      <main class="corps">
        <router-outlet />
      </main>

      <nav class="barre" aria-label="Navigation principale">
        <a routerLink="/" routerLinkActive="barre__lien--actif"
           [routerLinkActiveOptions]="{ exact: true }" class="barre__lien">
          <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
            <path d="m4 11 8-6.5 8 6.5v8a1 1 0 0 1-1 1h-4v-6h-6v6H5a1 1 0 0 1-1-1v-8Z"
                  stroke="currentColor" stroke-width="1.7" stroke-linejoin="round" />
          </svg>
          <span>Accueil</span>
        </a>

        <a routerLink="/catalogue" routerLinkActive="barre__lien--actif" class="barre__lien">
          <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
            <circle cx="11" cy="11" r="6.5" stroke="currentColor" stroke-width="1.7" />
            <path d="m16 16 4 4" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" />
          </svg>
          <span>Chercher</span>
        </a>

        <a routerLink="/panier" routerLinkActive="barre__lien--actif" class="barre__lien">
          <span class="barre__pastille">
            <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
              <path d="M4 5h2l2.2 9.5a2 2 0 0 0 2 1.5h6.4a2 2 0 0 0 2-1.5L20 8H7"
                    stroke="currentColor" stroke-width="1.7" stroke-linecap="round"
                    stroke-linejoin="round" />
            </svg>
            @if (panier.nombreArticles(); as n) {
              <span class="barre__compteur" [attr.aria-label]="n + ' article(s) au panier'">{{ n }}</span>
            }
          </span>
          <span>Panier</span>
        </a>

        <a routerLink="/mes-commandes" routerLinkActive="barre__lien--actif" class="barre__lien">
          <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
            <circle cx="12" cy="8.5" r="3.5" stroke="currentColor" stroke-width="1.7" />
            <path d="M5.5 20a6.5 6.5 0 0 1 13 0" stroke="currentColor" stroke-width="1.7"
                  stroke-linecap="round" />
          </svg>
          <span>Compte</span>
        </a>
      </nav>
    </div>
  `,
  styles: `
    .corps {
      flex: 1;
      /* ⚠️ De la place sous le contenu, sinon la barre recouvre le dernier
         bouton de chaque écran — et c'est souvent le bouton principal. */
      padding-bottom: 4.5rem;
    }

    .barre {
      position: fixed;
      bottom: 0;
      left: 50%;
      transform: translateX(-50%);
      width: 100%;
      max-width: 480px;
      display: grid;
      grid-template-columns: repeat(4, minmax(0, 1fr));
      background: var(--verre-fond);
      backdrop-filter: blur(16px);
      -webkit-backdrop-filter: blur(16px);
      border-top: 1px solid var(--verre-bordure);
      /* L'encoche des téléphones récents : sans cela, les libellés passent
         dessous et deviennent illisibles. */
      padding-bottom: env(safe-area-inset-bottom);
      z-index: 10;
    }

    .barre__lien {
      min-height: var(--cible-tactile-min);
      padding: 0.6rem 0.25rem;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      gap: 0.2rem;
      color: var(--texte-attenue);
      text-decoration: none;
      font-size: 0.66rem;
      font-weight: 500;

      svg { width: 21px; height: 21px; }
      &:focus-visible { outline: 2px solid var(--primaire); outline-offset: -2px; }
    }

    .barre__lien--actif {
      color: var(--primaire);
      font-weight: 600;
    }

    .barre__pastille { position: relative; display: inline-flex; }

    .barre__compteur {
      position: absolute;
      top: -5px;
      right: -8px;
      min-width: 16px;
      height: 16px;
      padding: 0 4px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      border-radius: 9999px;
      background: var(--primaire);
      color: #fff;
      font-size: 9.5px;
      font-weight: 700;
    }
  `,
})
export class Racine {
  protected readonly panier = inject(PanierLocal);
}
