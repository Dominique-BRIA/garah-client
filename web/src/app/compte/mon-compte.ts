import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { RouterLink } from '@angular/router';

import { ServiceFavoris } from '../../services/favoris';
import { ServiceSession } from '../../services/session';

/** Une porte de l'espace personnel. */
interface Entree {
  readonly lien: string;
  readonly titre: string;
  readonly aide: string;
  /** Les tracés de l'icône, en 24 × 24, dessinés au trait. */
  readonly traces: readonly string[];
}

/**
 * Mon compte : l'entrée de l'espace personnel.
 *
 * <h2>🎯 Des portes, et aucune liste</h2>
 *
 * <p>Il n'existait pas d'écran « Mon compte ». Le lien « Compte » menait à
 * <code>/mes-commandes</code>, qui portait tout à la fois : la déconnexion,
 * une rangée de six pastilles de navigation, la liste des commandes et la voie
 * de recours. Les commandes s'y affichaient au milieu d'une page qui n'était
 * pas la leur.</p>
 *
 * <p>Chaque rubrique a maintenant son écran, et celui-ci n'en montre que les
 * portes — exactement comme l'écran « Compte » de l'application Android.
 * Quelqu'un qui passe de l'un à l'autre retrouve les mêmes entrées, dans le
 * même ordre.</p>
 *
 * <p>⚠️ Les entrées ne sont pas toutes celles du téléphone, et ce n'est pas un
 * oubli : le web a un écran de profil que l'application n'a pas encore, et il
 * sépare retours et réclamations que l'application réunit. L'ordre, lui, est
 * le même.</p>
 */
@Component({
  selector: 'gb-mon-compte',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [RouterLink],
  template: `
    <header class="entete">
      <div>
        <h1>Mon compte</h1>
        @if (session.nom(); as nom) {
          <p class="entete__aide">{{ nom }}</p>
        }
      </div>
      <button type="button" class="gb-btn gb-btn--secondaire" (click)="seDeconnecter()">
        Se déconnecter
      </button>
    </header>

    <nav class="entrees" aria-label="Mon espace">
      @for (e of entrees; track e.lien) {
        <a class="entree" [routerLink]="e.lien">
          <svg class="entree__icone" viewBox="0 0 24 24" fill="none" aria-hidden="true">
            @for (d of e.traces; track d) {
              <path [attr.d]="d" stroke="currentColor" stroke-width="1.7"
                    stroke-linecap="round" stroke-linejoin="round" />
            }
          </svg>

          <span class="entree__texte">
            <span class="entree__titre">{{ e.titre }}</span>
            <span class="entree__aide">{{ e.aide }}</span>
          </span>

          <!-- Le compteur de « Ma liste » vivait dans la rangée de pastilles.
               Il suit l'entrée : c'est le seul chiffre qui dise, sans ouvrir,
               qu'il y a quelque chose derrière la porte. -->
          @if (e.lien === '/ma-liste' && favoris.nombre()) {
            <span class="entree__compteur">{{ favoris.nombre() }}</span>
          }

          <svg class="entree__fleche" viewBox="0 0 24 24" fill="none" aria-hidden="true">
            <path d="m9 6 6 6-6 6" stroke="currentColor" stroke-width="1.8"
                  stroke-linecap="round" stroke-linejoin="round" />
          </svg>
        </a>
      }
    </nav>
  `,
  styles: `
    .entete {
      padding: 1.5rem 1.25rem 1rem;
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 1rem;
    }

    .entete h1 { margin: 0; font-size: 1.3rem; font-weight: 700; }
    .entete__aide { margin: 0.25rem 0 0; font-size: 0.8rem; color: var(--texte-attenue); }

    .entrees {
      padding: 0 1.25rem 2rem;
      display: flex;
      flex-direction: column;
      gap: 0.6rem;
    }

    .entree {
      min-height: var(--cible-tactile-min);
      display: flex;
      align-items: center;
      gap: 0.9rem;
      padding: 0.85rem 1rem;
      border: 1px solid var(--verre-bordure);
      border-radius: var(--rayon-moyen);
      background: var(--surface);
      color: var(--texte);
      text-decoration: none;
      transition: border-color 0.2s ease-in-out;

      &:focus-visible { outline: 2px solid var(--primaire); outline-offset: 2px; }
    }

    /* ⚠️ --primaire-texte et non --primaire : l'indigo de la charte tombe sous
       4,5:1 sur la surface, dans un thème comme dans l'autre. */
    .entree__icone { width: 22px; height: 22px; flex-shrink: 0; color: var(--primaire-texte); }

    /* min-width: 0 — sans lui, une aide longue pousse la flèche hors de la
       carte au lieu de se replier. */
    .entree__texte { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 0.15rem; }
    .entree__titre { font-size: 0.92rem; font-weight: 600; }
    .entree__aide { font-size: 0.78rem; color: var(--texte-attenue); line-height: 1.4; }

    .entree__compteur {
      min-width: 20px;
      height: 20px;
      padding: 0 6px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      border-radius: 9999px;
      background: var(--primaire);
      color: #fff;
      font-size: 11px;
      font-weight: 700;
    }

    .entree__fleche { width: 16px; height: 16px; flex-shrink: 0; color: var(--texte-attenue); }

    @media (hover: hover) {
      .entree:hover { border-color: var(--primaire-clair); }
    }

    /* Sur écran large, une colonne de 40 rem : des portes étirées sur toute la
       largeur se lisent comme un tableau, et l'œil perd la flèche au bout. */
    @media (min-width: 900px) {
      .entete, .entrees { padding-left: 0; padding-right: 0; }
      .entrees { max-width: 40rem; }
    }
  `,
})
export class MonCompte {
  protected readonly session = inject(ServiceSession);
  protected readonly favoris = inject(ServiceFavoris);

  /**
   * Les portes, dans l'ordre de l'application Android : ce qu'on a acheté,
   * ce qu'on a mis de côté, ce qu'on a demandé, ce qui ne va pas.
   */
  protected readonly entrees: readonly Entree[] = [
    {
      lien: '/mes-commandes',
      titre: 'Mes commandes',
      aide: 'Suivre un achat, retrouver un code de retrait',
      traces: ['M6 3h12v18l-3-2-3 2-3-2-3 2V3Z', 'M9 8h6M9 12h6'],
    },
    {
      lien: '/ma-liste',
      titre: 'Ma liste',
      aide: 'Les articles mis de côté',
      traces: ['M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10Z'],
    },
    {
      lien: '/mes-discussions',
      titre: 'Mes discussions',
      aide: 'Vos questions, et les réponses de nos conseillers',
      traces: ['M5 5h14v10H9.5L5 19V5Z', 'M8.5 9h7M8.5 12h4.5'],
    },
    {
      lien: '/mes-reclamations',
      titre: 'Réclamations',
      aide: 'Signaler un problème sur une commande',
      traces: ['M4 12a8 8 0 1 0 16 0a8 8 0 1 0-16 0', 'M12 8v5M12 16h.01'],
    },
    {
      lien: '/mes-retours',
      titre: 'Retours',
      aide: 'Renvoyer un article',
      traces: ['M9 7 5 11l4 4', 'M5 11h9a5 5 0 0 1 0 10h-2'],
    },
    {
      lien: '/profil',
      titre: 'Mon profil',
      aide: 'Vos informations personnelles',
      traces: ['M8.5 8.5a3.5 3.5 0 1 0 7 0a3.5 3.5 0 1 0-7 0', 'M5.5 20a6.5 6.5 0 0 1 13 0'],
    },
    {
      lien: '/suivi',
      titre: 'Suivre un colis',
      aide: 'Avec un numéro de suivi, même sans compte',
      traces: [
        'M2 15h11V8H2v7Z',
        'M13 11h4.3l2.7 3v1h-7v-4Z',
        'M4.2 17.5a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0-3.6 0',
        'M14.7 17.5a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0-3.6 0',
      ],
    },
  ];

  protected seDeconnecter(): void {
    this.session.deconnecter().subscribe(() => {
      window.location.href = '/';
    });
  }
}
