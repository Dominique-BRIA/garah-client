import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { RouterLink, RouterLinkActive } from '@angular/router';

import { ServiceFavoris } from '../../services/favoris';

/**
 * La navigation de l'espace personnel.
 *
 * <h2>🎯 Sans elle, cinq écrans existaient sans porte</h2>
 *
 * <p>Retours, réclamations, discussions et liste d'envies ne se joignaient par
 * aucun lien : ils n'étaient atteignables qu'en tapant l'URL. Un écran qu'on
 * ne peut pas atteindre n'est pas un écran, c'est du code mort.</p>
 *
 * <p>⚠️ Elle n'est <b>pas</b> dans l'en-tête de la boutique. Cinq entrées de
 * plus dans une barre qui porte déjà la recherche, le panier et la connexion
 * noieraient l'acte d'achat sous la gestion de compte. La vitrine sert à
 * acheter ; ceci sert à suivre ce qu'on a acheté.</p>
 */
@Component({
  selector: 'gb-menu-compte',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [RouterLink, RouterLinkActive],
  template: `
    <nav class="menu" aria-label="Mon espace">
      <a routerLink="/mes-commandes" routerLinkActive="menu__lien--actif"
         [routerLinkActiveOptions]="{ exact: true }" class="menu__lien">Commandes</a>
      <a routerLink="/ma-liste" routerLinkActive="menu__lien--actif" class="menu__lien">
        Ma liste
        @if (favoris.nombre(); as n) {
          <span class="menu__compteur">{{ n }}</span>
        }
      </a>
      <a routerLink="/mes-retours" routerLinkActive="menu__lien--actif" class="menu__lien">Retours</a>
      <a routerLink="/mes-reclamations" routerLinkActive="menu__lien--actif" class="menu__lien">Réclamations</a>
      <a routerLink="/mes-discussions" routerLinkActive="menu__lien--actif" class="menu__lien">Discussions</a>
      <a routerLink="/profil" routerLinkActive="menu__lien--actif" class="menu__lien">Profil</a>
    </nav>
  `,
  styles: [
    `
      .menu {
        display: flex;
        gap: 0.4rem;
        padding: 0 1.25rem;
        /* Au téléphone, six entrées ne tiennent pas : la rangée défile d'un
           doigt plutôt que de se replier sur trois lignes. */
        overflow-x: auto;
        scrollbar-width: none;
      }

      .menu::-webkit-scrollbar { display: none; }

      .menu__lien {
        flex: 0 0 auto;
        min-height: 40px;
        display: inline-flex;
        align-items: center;
        gap: 0.4rem;
        padding: 0 0.85rem;
        border: 1px solid var(--verre-bordure);
        border-radius: 9999px;
        color: var(--texte-attenue);
        text-decoration: none;
        font-size: 0.82rem;
        font-weight: 600;
        white-space: nowrap;
        transition: color 0.2s ease-in-out, border-color 0.2s ease-in-out;
      }

      .menu__lien--actif {
        color: var(--primaire);
        border-color: color-mix(in srgb, var(--primaire) 45%, transparent);
        background: color-mix(in srgb, var(--primaire) 8%, transparent);
      }

      .menu__lien:focus-visible { outline: 2px solid var(--primaire); outline-offset: 2px; }

      .menu__compteur {
        min-width: 18px;
        height: 18px;
        padding: 0 5px;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        border-radius: 9999px;
        background: var(--primaire);
        color: #fff;
        font-size: 10px;
        font-weight: 700;
      }

      @media (hover: hover) {
        .menu__lien:hover { color: var(--texte); border-color: var(--texte-attenue); }
        .menu__lien--actif:hover { color: var(--primaire); }
      }

      @media (min-width: 900px) {
        .menu { padding: 0; flex-wrap: wrap; }
      }
    `,
  ],
})
export class MenuCompte {
  protected readonly favoris = inject(ServiceFavoris);
}
