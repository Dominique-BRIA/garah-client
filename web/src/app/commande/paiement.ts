import { HttpClient } from '@angular/common/http';
import { Component, inject, input, signal } from '@angular/core';
import { RouterLink } from '@angular/router';

import { montantLisible } from '../../modeles/catalogue';
import { messageErreur } from '../../api/erreurs';

interface EtatPaiement {
  readonly id: number;
  readonly statut: string;
  readonly montant: number;
  readonly moyen: string;
  readonly referenceTransaction: string | null;
}

type Moyen = 'MTN_MOMO' | 'ORANGE_MONEY';

/**
 * Le paiement mobile.
 *
 * <h2>🎯 JAMAIS DE SUCCÈS OPTIMISTE</h2>
 *
 * <p>Le client valide sur son téléphone ; GARAH l'apprend par un <b>webhook</b>
 * Campay qui peut mettre plusieurs secondes — ou ne jamais arriver.</p>
 *
 * <p>Afficher « payé » avant confirmation ferait repartir un client persuadé
 * d'avoir réglé. Le litige qui suit coûte plus cher que l'attente.</p>
 *
 * <p>D'où l'état d'attente explicite, le bouton qui redemande l'état à
 * l'opérateur, et une <b>sortie honnête</b> si rien n'arrive : la commande
 * reste en attente de paiement, rien n'est perdu.</p>
 */
@Component({
  selector: 'gb-paiement',
  imports: [RouterLink],
  template: `
    <header class="entete">
      <h1>Paiement</h1>
      <p class="entete__aide gb-mono">Commande n° {{ id() }}</p>
    </header>

    @if (erreur(); as m) {
      <p class="gb-alerte marge" role="alert">{{ m }}</p>
    }

    @if (!paiement()) {
      <!-- Choix du moyen, avant tout envoi. -->
      <section class="bloc">
        <p class="gb-libelle">Moyen de paiement</p>
        <div class="moyens">
          <button type="button" class="moyen" [class.moyen--choisi]="moyen() === 'MTN_MOMO'"
                  (click)="moyen.set('MTN_MOMO')">MTN MoMo</button>
          <button type="button" class="moyen" [class.moyen--choisi]="moyen() === 'ORANGE_MONEY'"
                  (click)="moyen.set('ORANGE_MONEY')">Orange Money</button>
        </div>

        <!-- ⚠️ LE NUMÉRO EST DEMANDÉ, ET IL DOIT L'ÊTRE.
             L'écran n'envoyait AUCUN numéro. Le serveur en exige un — c'est
             lui qui part chez l'opérateur et qui recevra la demande de
             validation — et le paiement échouait donc toujours, sur un
             message qui n'expliquait rien : « Le numéro de téléphone est
             obligatoire. »

             Il est PRÉ-REMPLI depuis le profil, mais reste modifiable : on
             paie souvent avec un autre numéro que celui du compte — celui
             d'un proche, ou son second opérateur. Le figer obligerait à
             changer son profil pour payer. -->
        <label class="gb-libelle" for="p-tel">Numéro Mobile Money</label>
        <input id="p-tel" type="tel" class="gb-champ" placeholder="+237 6 99 00 00 00"
               [value]="telephone()" (input)="telephone.set($any($event.target).value)"
               [disabled]="envoi()" />
        <p class="aide-champ">
          @if (moyen() === 'MTN_MOMO') {
            Ce numéro MTN recevra la demande de validation.
          } @else {
            Ce numéro Orange recevra la demande de validation.
          }
        </p>

        <button type="button" class="gb-btn gb-btn--primaire gb-btn--plein"
                [disabled]="envoi() || telephone().trim() === ''" (click)="lancer()">
          @if (envoi()) { Envoi… } @else { Payer }
        </button>
      </section>
    } @else if (paiement(); as p) {
      <section class="gb-carte attente">
        <div class="attente__pastille" aria-hidden="true">
          <svg viewBox="0 0 24 24" fill="none">
            <rect x="6" y="2.5" width="12" height="19" rx="2.4" stroke="var(--alerte)" stroke-width="1.7" />
            <path d="M10.5 18.5h3" stroke="var(--alerte)" stroke-width="1.7" stroke-linecap="round" />
          </svg>
        </div>

        <h2>Validez sur votre téléphone</h2>
        <p class="attente__texte">
          Une demande de paiement vous a été envoyée. Saisissez votre code pour
          confirmer.
        </p>

        <div class="attente__montant">
          <span class="gb-attenue">Montant</span>
          <span class="gb-montant">{{ montant(p.montant) }}</span>
        </div>

        <p class="attente__statut">En attente de votre validation</p>
      </section>

      <div class="bloc">
        <button type="button" class="gb-btn gb-btn--secondaire gb-btn--plein"
                [disabled]="verification()" (click)="verifier()">
          @if (verification()) { Vérification… } @else { J’ai validé — vérifier }
        </button>
        <p class="aide">La confirmation peut prendre quelques secondes.</p>
      </div>

      <!-- LA SORTIE HONNÊTE. Rien n'est perdu, et le dire évite de recommander. -->
      <section class="secours">
        <p class="secours__titre">Si rien n’arrive</p>
        <p class="secours__texte">
          Votre commande est conservée telle quelle. Vous pourrez reprendre le
          paiement depuis « Mes commandes ».
        </p>
        <a routerLink="/mes-commandes" class="gb-btn gb-btn--secondaire">Mes commandes</a>
      </section>
    }
  `,
  styles: `
    .entete { padding: 1.5rem 1.25rem 1rem; }
    .entete h1 { margin: 0; font-size: 1.3rem; font-weight: 700; }
    .entete__aide { margin: 0.3rem 0 0; font-size: 0.8rem; color: var(--texte-attenue); }

    .marge { margin: 0 1.25rem 1rem; }

    .bloc { padding: 0 1.25rem 1.25rem; display: flex; flex-direction: column; gap: 0.7rem; }
    .aide { margin: 0; text-align: center; font-size: 0.75rem; color: var(--texte-attenue); }

    .moyens { display: flex; gap: 0.6rem; }

    // ⚠️ Un nom PROPRE a ce champ, et non .aide : cette classe existe deja
    //    plus haut, centree, pour le mot d attente. Reutiliser le nom aurait
    //    melange les deux styles sans que rien ne le signale.
    .aide-champ { margin: 0.5rem 0 0.9rem; font-size: 0.78rem; line-height: 1.5; color: var(--texte-attenue); }

    .moyen {
      flex: 1;
      min-height: var(--cible-tactile-min);
      padding: 0.7rem;
      border-radius: var(--rayon-moyen);
      border: 1px solid var(--verre-bordure);
      background: var(--verre-fond);
      color: var(--texte-attenue);
      font-family: inherit;
      font-size: 0.85rem;
      font-weight: 600;
      cursor: pointer;

      &:focus-visible { outline: 2px solid var(--primaire); outline-offset: 2px; }
    }

    .moyen--choisi {
      border: 2px solid var(--primaire);
      background: color-mix(in srgb, var(--primaire) 6%, transparent);
      color: var(--texte);
    }

    .attente {
      margin: 0 1.25rem 1.25rem;
      padding: 1.6rem 1.25rem;
      display: flex;
      flex-direction: column;
      align-items: center;
      text-align: center;
      gap: 0.9rem;

      h2 { margin: 0; font-size: 1.05rem; font-weight: 700; }
    }

    .attente__pastille {
      width: 72px; height: 72px;
      display: flex; align-items: center; justify-content: center;
      border-radius: 50%;
      background: color-mix(in srgb, var(--alerte) 12%, transparent);

      svg { width: 34px; height: 34px; }
    }

    .attente__texte { margin: 0; font-size: 0.85rem; color: var(--texte-attenue); line-height: 1.55; }

    .attente__montant {
      width: 100%;
      padding: 0.8rem 0.9rem;
      display: flex;
      align-items: center;
      justify-content: space-between;
      border-radius: var(--rayon-moyen);
      background: var(--surface-douce);
      font-size: 0.85rem;
    }

    .attente__montant .gb-montant { font-size: 1.05rem; }

    .attente__statut { margin: 0; font-size: 0.8rem; font-weight: 600; color: var(--alerte); }

    .secours {
      margin: 0 1.25rem 1.5rem;
      padding: 1rem;
      border-radius: var(--rayon-moyen);
      border: 1px solid var(--verre-bordure);
      display: flex;
      flex-direction: column;
      gap: 0.5rem;
      align-items: flex-start;
    }

    .secours__titre { margin: 0; font-size: 0.85rem; font-weight: 600; }
    .secours__texte { margin: 0; font-size: 0.8rem; color: var(--texte-attenue); line-height: 1.55; }
  `,
})
export class Paiement {
  private readonly http = inject(HttpClient);

  readonly id = input.required<string>();

  protected readonly moyen = signal<Moyen>('MTN_MOMO');

  /** Le numero qui recevra la demande de validation. */
  protected readonly telephone = signal('');
  protected readonly paiement = signal<EtatPaiement | null>(null);

  protected readonly envoi = signal(false);
  protected readonly verification = signal(false);
  protected readonly erreur = signal<string | null>(null);

  constructor() {
    this.prefillerLeNumero();
  }

  /**
   * Pré-remplit le numéro depuis le profil.
   *
   * <p>⚠️ Son échec ne se signale PAS. Le champ reste vide et se saisit à la
   * main : afficher une erreur ferait croire que le paiement est en panne
   * alors qu'il ne manque qu'une commodité.</p>
   */
  private prefillerLeNumero(): void {
    this.http.get<{ telephone: string | null }>('/api/profil').subscribe({
      next: (p) => {
        const numero = p.telephone?.trim();
        // On n'écrase pas ce qui a déjà été tapé : la réponse peut arriver
        // après que le client a commencé à saisir.
        if (numero && this.telephone() === '') {
          this.telephone.set(numero);
        }
      },
      error: () => {
        // Voir la javadoc : volontairement muet.
      },
    });
  }

  protected lancer(): void {
    if (this.envoi()) {
      return;
    }
    this.envoi.set(true);
    this.erreur.set(null);

    this.http
      .post<EtatPaiement>('/api/paiements', {
        commandeId: Number(this.id()),
        moyen: this.moyen(),
        // ⚠️ Il MANQUAIT. Le serveur l exige — c est ce numero qui part chez
        //    l operateur et recevra la demande de validation — et le paiement
        //    echouait donc toujours.
        telephone: this.telephone().trim(),
      })
      .subscribe({
        next: (p) => {
          this.envoi.set(false);
          this.paiement.set(p);
        },
        error: (e: unknown) => {
          this.envoi.set(false);
          this.erreur.set(messageErreur(e, 'Le paiement n’a pas pu être lancé.'));
        },
      });
  }

  /**
   * Redemande l'état à l'opérateur.
   *
   * <p>Sans attendre la réconciliation nocturne : le client est devant son
   * écran, il vient de valider, et lui dire « revenez demain » n'est pas une
   * réponse.</p>
   */
  protected verifier(): void {
    const p = this.paiement();
    if (!p || this.verification()) {
      return;
    }
    this.verification.set(true);
    this.erreur.set(null);

    this.http.post<EtatPaiement>(`/api/paiements/${p.id}/verification`, {}).subscribe({
      next: (maj) => {
        this.verification.set(false);
        this.paiement.set(maj);

        if (maj.statut === 'CONFIRME') {
          // Confirmé pour de bon, par le serveur — jamais deviné ici.
          window.location.href = '/mes-commandes';
        }
      },
      error: (e: unknown) => {
        this.verification.set(false);
        this.erreur.set(messageErreur(e, 'Le paiement n’a pas pu être lancé.'));
      },
    });
  }

  protected montant(valeur: number): string {
    return montantLisible(valeur);
  }
}

