import { HttpClient } from '@angular/common/http';
import { Component, computed, inject, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { catchError, of } from 'rxjs';

import { montantLisible } from '../../modeles/catalogue';
import { messageErreur } from '../../api/erreurs';
import { PanierLocal } from '../../services/panier-local';
import { ServiceSession } from '../../services/session';

/** Un point de récupération, tel que la route publique le rend. */
interface PointRecuperation {
  readonly id: number;
  readonly nom: string;
  readonly ville: string;
  readonly pays: string;
  readonly adresse: string | null;
  readonly horaires: string | null;
  readonly fraisAcheminement: number;
}

interface LignePanier {
  readonly varianteId: number;
  readonly designation: string;
  readonly quantite: number;
  readonly prixUnitaire: number;
  readonly montantLigne: number;
  readonly vendable: boolean;
  /*
   * Vrai si le prix vient d'une negociation acceptee dans une discussion.
   * Le dire : sinon le client verrait un prix different de la fiche produit
   * et croirait a une erreur — dans un sens ou dans l'autre.
   */
  readonly prixNegocie?: boolean;
}

interface ContenuPanier {
  readonly lignes: readonly LignePanier[];
  readonly montantArticles: number;
  readonly nombreArticles: number;
  readonly indisponibles: readonly string[];
}

/**
 * Passer commande.
 *
 * <h2>🎯 UN SEUL ÉCRAN, pas un tunnel</h2>
 *
 * <p>Il n'y a ni adresse, ni transporteur, ni créneau à choisir : GARAH ne
 * livre pas à domicile (D-05). Le seul choix réel est le <b>lieu de
 * retrait</b> — et il change le total, puisqu'il porte les frais
 * d'acheminement.</p>
 *
 * <p>Un tunnel en quatre étapes ferait abandonner pour rien.</p>
 *
 * <p>⚠️ Le panier lu ici est celui du <b>serveur</b>, pas le panier local :
 * lui seul connaît le stock, les paliers de quantité et le prix du jour.</p>
 */
@Component({
  selector: 'gb-commande',
  imports: [RouterLink],
  template: `
    <header class="entete">
      <h1>Passer la commande</h1>
      <p class="entete__aide">Un seul choix : où retirer.</p>
    </header>

    @if (erreur(); as m) {
      <p class="gb-alerte marge" role="alert">{{ m }}</p>
    }

    @if (chargement()) {
      <div class="gb-etat"><p>Chargement…</p></div>
    } @else {

      <!-- Ce que le serveur refuse de vendre. À dire AVANT le bouton : le
           découvrir après le clic ferait revenir en arrière. -->
      @if (panier()?.indisponibles?.length) {
        <p class="gb-alerte marge" role="alert">
          Certains articles ne sont plus disponibles et ne seront pas commandés :
          {{ panier()!.indisponibles.join(', ') }}
        </p>
      }

      <section class="bloc">
        <p class="gb-libelle">Point de récupération</p>

        @for (p of points(); track p.id) {
          <button type="button" class="point" [class.point--choisi]="p.id === pointId()"
                  (click)="pointId.set(p.id)">
            <span class="point__marque" aria-hidden="true"></span>
            <span class="point__corps">
              <span class="point__tete">
                <span class="point__nom">{{ p.nom }}</span>
                <span class="point__frais">{{ montant(p.fraisAcheminement) }}</span>
              </span>
              @if (p.adresse) { <span class="point__detail">{{ p.adresse }}</span> }
              @if (p.horaires) { <span class="point__detail">{{ p.horaires }}</span> }
            </span>
          </button>
        }

        <!-- Ni adresse, ni livraison. Le dire évite de chercher le champ. -->
        <p class="bloc__aide">
          GARAH ne livre pas à domicile. Vous retirez vous-même, avec un code
          qu’on vous remettra.
        </p>
      </section>

      @if (panier(); as c) {
        <section class="gb-carte recap">
          <p class="gb-libelle">Votre commande</p>

          @for (l of c.lignes; track l.varianteId) {
            <div class="recap__ligne">
              <span>
                {{ l.designation }} <span class="gb-attenue">× {{ l.quantite }}</span>
                @if (l.prixNegocie) { <span class="gb-attenue">· prix négocié</span> }
              </span>
              <span class="gb-montant">{{ montant(l.montantLigne) }}</span>
            </div>
          }

          <div class="recap__ligne">
            <span class="gb-attenue">Acheminement</span>
            <span class="gb-montant">{{ montant(frais()) }}</span>
          </div>

          <div class="recap__separateur"></div>

          <div class="recap__ligne recap__ligne--total">
            <span>À payer</span>
            <span class="gb-montant recap__total">{{ montant(total()) }}</span>
          </div>

          <!-- Les montants sont figés ICI. Le dire avant, pas après. -->
          <p class="recap__mention">
            Ces montants sont figés à la validation. Ils ne bougeront plus, même
            si les tarifs changent.
          </p>
        </section>

        <div class="actions">
          <button type="button" class="gb-btn gb-btn--primaire gb-btn--plein"
                  [disabled]="pointId() === null || envoi() || c.lignes.length === 0"
                  (click)="valider()">
            @if (envoi()) { Validation… } @else { Valider et payer }
          </button>
          <!-- On ne s'annule pas soi-même après paiement (D-12) : le dire AVANT
               de payer, pas au moment de le découvrir. -->
          <p class="actions__mention">
            Une fois payée, une commande s’annule en nous écrivant, pas d’un clic.
          </p>
        </div>
      } @else {
        <div class="gb-etat">
          <p>Votre panier est vide.</p>
          <a routerLink="/catalogue" class="gb-btn gb-btn--secondaire">Parcourir le catalogue</a>
        </div>
      }
    }
  `,
  styles: `
    .entete { padding: 1.5rem 1.25rem 1rem; }
    .entete h1 { margin: 0; font-size: 1.3rem; font-weight: 700; }
    .entete__aide { margin: 0.3rem 0 0; font-size: 0.82rem; color: var(--texte-attenue); }

    .marge { margin: 0 1.25rem 1rem; }

    .bloc { padding: 0 1.25rem; display: flex; flex-direction: column; gap: 0.6rem; }
    .bloc__aide { margin: 0.3rem 0 0; font-size: 0.78rem; color: var(--texte-attenue); line-height: 1.55; }

    .point {
      display: flex;
      align-items: flex-start;
      gap: 0.75rem;
      width: 100%;
      min-height: var(--cible-tactile-min);
      padding: 0.9rem;
      border-radius: var(--rayon-moyen);
      border: 1px solid var(--verre-bordure);
      background: var(--verre-fond);
      color: inherit;
      font-family: inherit;
      text-align: left;
      cursor: pointer;

      &:focus-visible { outline: 2px solid var(--primaire); outline-offset: 2px; }
    }

    .point--choisi {
      border: 2px solid var(--primaire);
      background: color-mix(in srgb, var(--primaire) 6%, transparent);

      .point__marque { border: 6px solid var(--primaire); }
    }

    .point__marque {
      width: 20px; height: 20px; flex-shrink: 0; margin-top: 0.1rem;
      border-radius: 50%;
      border: 1px solid var(--champ-bordure);
      background: var(--surface);
    }

    .point__corps { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 0.2rem; }

    .point__tete { display: flex; align-items: baseline; justify-content: space-between; gap: 0.6rem; }
    .point__nom { font-size: 0.9rem; font-weight: 600; }
    .point__frais { font-size: 0.85rem; font-weight: 700; white-space: nowrap; font-variant-numeric: tabular-nums; }
    .point__detail { font-size: 0.78rem; color: var(--texte-attenue); line-height: 1.45; }

    .recap { margin: 1.25rem 1.25rem 0; padding: 1rem; display: flex; flex-direction: column; gap: 0.55rem; }
    .recap__ligne { display: flex; align-items: baseline; justify-content: space-between; gap: 0.75rem; font-size: 0.85rem; }
    .recap__ligne--total { font-size: 1rem; font-weight: 700; }
    .recap__total { font-size: 1.3rem; }
    .recap__separateur { height: 1px; background: var(--verre-bordure); margin: 0.2rem 0; }
    .recap__mention { margin: 0.3rem 0 0; font-size: 0.75rem; color: var(--texte-attenue); line-height: 1.55; }

    .actions { padding: 1.25rem; display: flex; flex-direction: column; gap: 0.6rem; }
    .actions__mention { margin: 0; text-align: center; font-size: 0.75rem; color: var(--texte-attenue); line-height: 1.5; }
  `,
})
export class Commande {
  private readonly http = inject(HttpClient);
  private readonly router = inject(Router);
  private readonly session = inject(ServiceSession);
  private readonly panierLocal = inject(PanierLocal);

  protected readonly points = signal<readonly PointRecuperation[]>([]);
  protected readonly panier = signal<ContenuPanier | null>(null);
  protected readonly pointId = signal<number | null>(null);

  protected readonly chargement = signal(true);
  protected readonly envoi = signal(false);
  protected readonly erreur = signal<string | null>(null);

  protected readonly frais = computed(
    () => this.points().find((p) => p.id === this.pointId())?.fraisAcheminement ?? 0,
  );

  protected readonly total = computed(
    () => (this.panier()?.montantArticles ?? 0) + this.frais(),
  );

  constructor() {
    this.charger();
  }

  /**
   * Les points de récupération et le panier.
   *
   * <p>⚠️ LE PANIER LOCAL EST POUSSÉ AU SERVEUR AVANT D'ÊTRE RELU. L'écran lit
   * {@code /api/panier} — le panier du serveur — alors que l'écran précédent
   * affiche celui du navigateur. Sans cette synchronisation, tout ce qu'un
   * client déjà connecté a ajouté restait dans son navigateur, et cet écran
   * annonçait « Votre panier est vide » sur un panier qui affichait ses lignes
   * et son montant.</p>
   *
   * <p>La synchronisation est faite ICI et non sur le bouton de l'écran
   * précédent : on arrive aussi sur {@code /commande} par l'URL, par le retour
   * arrière, ou après une connexion qui redirige. Un seul de ces chemins passe
   * par le bouton.</p>
   *
   * <p>⚠️ Son échec n'empêche PAS de continuer. Le serveur a peut-être déjà le
   * panier — d'une session précédente, d'un autre appareil. S'arrêter là
   * priverait d'une commande possible ; on relit donc le panier serveur et
   * c'est lui qui dira s'il est vide.</p>
   */
  private charger(): void {
    this.chargement.set(true);

    this.http.get<PointRecuperation[]>('/api/lieux/points-recuperation').subscribe({
      next: (p) => {
        this.points.set(p);
        // Le moins cher d'abord : c'est le choix par défaut le plus sûr, et
        // celui qu'on regrette le moins si on ne regarde pas.
        const moinsCher = [...p].sort((a, b) => a.fraisAcheminement - b.fraisAcheminement)[0];
        this.pointId.set(moinsCher?.id ?? null);
      },
      error: () => this.erreur.set('Les points de récupération n’ont pas pu être chargés.'),
    });

    this.session
      .synchroniserLePanier()
      .pipe(catchError(() => of(null)))
      .subscribe(() => this.lirePanier());
  }

  private lirePanier(): void {
    this.http.get<ContenuPanier>('/api/panier').subscribe({
      next: (c) => {
        this.panier.set(c.lignes.length > 0 ? c : null);
        this.chargement.set(false);
      },
      error: () => {
        this.chargement.set(false);
        this.erreur.set('Votre panier n’a pas pu être chargé.');
      },
    });
  }

  protected valider(): void {
    const point = this.pointId();
    if (point === null || this.envoi()) {
      return;
    }
    this.envoi.set(true);
    this.erreur.set(null);

    this.http
      .post<{ id: number }>('/api/commandes', { pointRecuperationId: point, langue: 'fr' })
      .subscribe({
        next: (c) => {
          this.envoi.set(false);
          // ⚠️ LE PANIER LOCAL SE VIDE ICI, et pas avant.
          //
          //    La commande est passée : le serveur a consommé SON panier, et
          //    le local n'a plus de raison d'être. Le vider plus tôt — à la
          //    synchronisation, comme le faisait l'ancienne fusion — vidait
          //    l'écran du panier alors qu'aucune commande n'était passée.
          this.panierLocal.vider();
          void this.router.navigate(['/paiement', c.id]);
        },
        error: (e: unknown) => {
          this.envoi.set(false);
          this.erreur.set(messageErreur(e, 'La commande n’a pas pu être créée.'));
        },
      });
  }

  protected montant(valeur: number): string {
    return montantLisible(valeur);
  }
}

