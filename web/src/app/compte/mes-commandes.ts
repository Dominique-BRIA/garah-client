import { HttpClient } from '@angular/common/http';
import { Component, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';

import { Page, montantLisible } from '../../modeles/catalogue';
import { RetourCompte } from './retour-compte';

interface ResumeCommandeClient {
  readonly id: number;
  readonly numero: string;
  readonly statut: string;
  readonly montantTotal: number;
  readonly devise: string;
  readonly dateCreation: string;
  readonly nombreLignes: number;
}

const LIBELLES: Record<string, { texte: string; classe: string }> = {
  EN_ATTENTE_PAIEMENT: { texte: 'À payer', classe: 'gb-etiquette--alerte' },
  PAYEE: { texte: 'Payée', classe: 'gb-etiquette--info' },
  EN_PREPARATION: { texte: 'En préparation', classe: 'gb-etiquette--info' },
  PRETE: { texte: 'Prête', classe: 'gb-etiquette--info' },
  EXPEDIEE: { texte: 'En route', classe: 'gb-etiquette--info' },
  DISPONIBLE: { texte: 'À retirer', classe: 'gb-etiquette--succes' },
  RETIREE: { texte: 'Retirée', classe: 'gb-etiquette--neutre' },
  ANNULEE: { texte: 'Annulée', classe: 'gb-etiquette--neutre' },
};

/**
 * Mes commandes.
 *
 * <p>⚠️ Le <b>code de retrait</b> n'est pas dans cette liste : il se demande
 * sur la fiche d'une commande arrivée, et il ne voyage jamais dans une URL.
 * L'afficher ici le ferait apparaître dans une capture d'écran partagée.</p>
 *
 * <p>Une commande impayée reste <b>reprenable</b> : le paiement mobile échoue
 * souvent sans que rien ne soit perdu, et le dire évite de recommander.</p>
 */
@Component({
  selector: 'gb-mes-commandes',
  imports: [RouterLink, RetourCompte],
  template: `
    <!-- La déconnexion et le nom sont partis sur « Mon compte » : cet écran
         ne parle plus que des commandes. -->
    <gb-retour-compte />

    <header class="entete">
      <div>
        <h1>Mes commandes</h1>
        <p class="entete__aide">
          Vos achats et leur état. Ouvrez une commande arrivée pour voir son code
          de retrait.
        </p>
      </div>
    </header>


    @if (erreur(); as m) {
      <div class="gb-etat">
        <p>{{ m }}</p>
        <button type="button" class="gb-btn gb-btn--secondaire" (click)="charger()">Réessayer</button>
      </div>
    } @else if (chargement()) {
      <div class="gb-etat"><p>Chargement…</p></div>
    } @else if (commandes().length === 0) {
      <div class="gb-etat">
        <p>Vous n’avez pas encore commandé.</p>
        <a routerLink="/catalogue" class="gb-btn gb-btn--secondaire">Parcourir le catalogue</a>
      </div>
    } @else {
      <div class="liste">
        @for (c of commandes(); track c.id) {
          <article class="gb-carte commande">
            <div class="commande__tete">
              <div>
                <p class="commande__numero gb-mono">{{ c.numero }}</p>
                <p class="commande__detail">
                  {{ c.nombreLignes }} article(s) · {{ montant(c.montantTotal, c.devise) }}
                </p>
              </div>
              <span class="gb-etiquette" [class]="classe(c.statut)">{{ libelle(c.statut) }}</span>
            </div>

            @if (c.statut === 'EN_ATTENTE_PAIEMENT') {
              <p class="commande__mention">
                Le paiement n’a pas été confirmé. Votre commande vous attend telle quelle.
              </p>
              <a [routerLink]="['/paiement', c.id]" class="gb-btn gb-btn--primaire">
                Reprendre le paiement
              </a>
            }

            <!-- ⚠️ Un LIEN, et non la carte entière rendue cliquable : elle
                 contient déjà « Reprendre le paiement », et deux liens
                 imbriqués ne sont pas du HTML valide — le navigateur en perd
                 un, et lequel dépend de lui. -->
            <a [routerLink]="['/mes-commandes', c.id]" class="commande__lien">
              Voir le détail
              @if (c.statut === 'DISPONIBLE') {
                <!-- Ce qui donne envie d'ouvrir : le code de retrait est là,
                     et nulle part ailleurs. -->
                <span class="commande__appel">et le code de retrait</span>
              }
            </a>
          </article>
        }
      </div>
    }

    <!-- La voie de recours. Elle est ICI parce qu'on ne s'annule pas soi-même
         après paiement : sans elle, la règle serait simplement brutale. -->
    <!-- ⚠️ La voie de recours est un LIEN, plus une phrase. Dire « écrivez-nous »
         sans dire où revient à ne rien dire : on cherchait une adresse
         introuvable, et on renonçait. -->
    <p class="recours">
      Un problème sur une commande ?
      <a routerLink="/mes-reclamations">Ouvrez une réclamation</a> — un
      conseiller l’examine.
    </p>
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

    .liste { padding: 0 1.25rem; display: flex; flex-direction: column; gap: 0.75rem; }

    .commande { padding: 1rem; display: flex; flex-direction: column; gap: 0.7rem; }

    .commande__tete {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 0.75rem;
    }

    .commande__numero { margin: 0; font-size: 0.9rem; font-weight: 700; }
    .commande__detail { margin: 0.2rem 0 0; font-size: 0.78rem; color: var(--texte-attenue); }

    .commande__mention { margin: 0; font-size: 0.8rem; color: var(--texte-attenue); line-height: 1.5; }

    .commande__lien {
      /* 44 px, comme partout : un lien de carte se rate autant qu'un bouton. */
      min-height: var(--cible-tactile-min);
      display: inline-flex;
      align-items: center;
      gap: 0.4rem;
      align-self: flex-start;
      font-size: 0.83rem;
      font-weight: 600;
      color: var(--primaire);
      text-decoration: none;

      &:focus-visible { outline: 2px solid var(--primaire); outline-offset: 2px; }
    }

    .commande__appel { color: var(--succes); font-weight: 700; }

    @media (hover: hover) {
      .commande__lien:hover { text-decoration: underline; }
    }

    .recours {
      padding: 1.5rem 1.25rem;
      text-align: center;
      font-size: 0.8rem;
      color: var(--texte-attenue);
      line-height: 1.55;
    }
  `,
})
export class MesCommandes {
  private readonly http = inject(HttpClient);

  protected readonly commandes = signal<readonly ResumeCommandeClient[]>([]);
  protected readonly chargement = signal(true);
  protected readonly erreur = signal<string | null>(null);

  constructor() {
    this.charger();
  }

  protected charger(): void {
    this.chargement.set(true);
    this.erreur.set(null);

    this.http.get<Page<ResumeCommandeClient>>('/api/commandes/miennes?taille=25').subscribe({
      next: (p) => {
        this.commandes.set(p.content);
        this.chargement.set(false);
      },
      error: () => {
        this.chargement.set(false);
        this.erreur.set('Vos commandes n’ont pas pu être chargées.');
      },
    });
  }

  protected libelle(statut: string): string {
    return LIBELLES[statut]?.texte ?? statut;
  }

  protected classe(statut: string): string {
    return LIBELLES[statut]?.classe ?? 'gb-etiquette--neutre';
  }

  protected montant(valeur: number, devise: string): string {
    return montantLisible(valeur, devise);
  }
}
