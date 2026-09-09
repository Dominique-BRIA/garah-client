import { HttpClient } from '@angular/common/http';
import { Component, computed, effect, inject, input, signal } from '@angular/core';
import { RouterLink } from '@angular/router';

import { messageErreur } from '../../api/erreurs';
import { ServiceSession } from '../../services/session';

/** Ce que l'écran est en train de vivre. */
type Etat = 'attente' | 'confirme' | 'perime' | 'echec' | 'sansJeton';

/**
 * La confirmation d'adresse e-mail.
 *
 * <h2>🎯 Cet écran manquait, et son absence coûtait des ventes</h2>
 *
 * <p>On ne peut pas commander tant que son adresse n'est pas confirmée : le
 * serveur répond {@code ADRESSE_NON_CONFIRMEE}. Le lien du courriel est donc
 * la porte la plus importante du parcours.</p>
 *
 * <p>Ce lien se construit à partir de {@code GARAH_URL_VERIFICATION}, et le
 * nom de la variable invitait à la faire pointer ici. <b>Sauf que cette page
 * n'existait pas</b> : la route était absente, la règle de repli
 * ({@code ** → accueil}) attrapait la visite, et le jeton était perdu en
 * silence.</p>
 *
 * <p>⚠️ Le pire est que <b>tout avait l'air normal</b> : le courriel partait,
 * le lien ouvrait bien la boutique, l'accueil s'affichait sans un message. Le
 * client se croyait confirmé, et découvrait le refus des semaines plus tard,
 * au moment de payer — sans que personne puisse relier les deux.</p>
 *
 * <h2>Les quatre issues, et pourquoi chacune a son écran</h2>
 *
 * <pre>
 * attente    l'appel est en cours
 * confirme   c'est fait — on propose la suite, on ne laisse pas en plan
 * perime     410 : expiré, déjà utilisé, ou inconnu. Un seul message
 * echec      le réseau. ⚠️ N'est PAS « lien invalide » : on ne dit pas à
 *            quelqu'un que son lien est mort quand c'est la connexion
 * sansJeton  l'adresse a été ouverte à la main, sans `?jeton=`
 * </pre>
 */
@Component({
  selector: 'gb-verification',
  imports: [RouterLink],
  template: `
    <section class="carte">
      @switch (etat()) {
        @case ('attente') {
          <h1>Confirmation en cours…</h1>
          <p class="aide">Un instant, nous vérifions votre lien.</p>
        }

        @case ('confirme') {
          <h1>Votre adresse est confirmée</h1>
          <p class="aide">
            Vous pouvez maintenant commander sur GARAH.
          </p>
          <!-- ⚠️ On ne laisse jamais sur une impasse : la personne venait de
               sa boîte mail, elle n'a aucune navigation derrière elle. -->
          <a routerLink="/catalogue" class="gb-btn gb-btn--primaire gb-btn--plein">
            Voir les articles
          </a>
        }

        @case ('perime') {
          <h1>Ce lien n’est plus valide</h1>
          <p class="aide">{{ message() }}</p>

          @if (session.connecte()) {
            @if (renvoye()) {
              <p class="succes" role="status">
                Un nouveau lien vient de partir. Regardez votre boîte mail —
                et vos courriers indésirables.
              </p>
            } @else {
              <button type="button" class="gb-btn gb-btn--primaire gb-btn--plein"
                      [disabled]="renvoi()" (click)="renvoyer()">
                @if (renvoi()) { Envoi… } @else { M’envoyer un nouveau lien }
              </button>
            }
            @if (echecRenvoi(); as m) {
              <p class="gb-alerte" role="alert">{{ m }}</p>
            }
          } @else {
            <!-- ⚠️ Le renvoi EXIGE d'être connecté, et c'est délibéré côté
                 serveur : ouvert aux anonymes, il deviendrait un outil d'envoi
                 de courriels vers n'importe quelle adresse, à notre nom.

                 Un compte non confirmé PEUT se connecter — c'est justement ce
                 qui rend ce chemin possible. -->
            <p class="aide">
              Connectez-vous pour en demander un nouveau.
            </p>
            <a routerLink="/connexion" [queryParams]="{ suite: '/verification' }"
               class="gb-btn gb-btn--primaire gb-btn--plein">
              Se connecter
            </a>
          }
        }

        @case ('echec') {
          <h1>La confirmation n’a pas abouti</h1>
          <p class="aide">{{ message() }}</p>
          <button type="button" class="gb-btn gb-btn--primaire gb-btn--plein"
                  (click)="confirmer()">
            Réessayer
          </button>
        }

        @case ('sansJeton') {
          <h1>Lien incomplet</h1>
          <p class="aide">
            Cette adresse doit être ouverte depuis le lien reçu par courriel.
            Il est possible qu’il ait été coupé en le recopiant.
          </p>
          <a routerLink="/" class="gb-btn gb-btn--secondaire gb-btn--plein">
            Retour à l’accueil
          </a>
        }
      }
    </section>
  `,
  styles: `
    .carte {
      max-width: 26rem;
      margin: 3rem auto;
      padding: 0 1.25rem;
      text-align: center;
    }
    h1 {
      margin: 0 0 0.5rem;
      font-size: 1.3rem;
      font-weight: 700;
    }
    .aide {
      margin: 0 0 1.5rem;
      font-size: 0.9rem;
      line-height: 1.6;
      color: var(--texte-attenue);
    }
    .succes {
      margin: 0;
      font-size: 0.9rem;
      line-height: 1.6;
      color: var(--texte);
    }
    .gb-alerte { margin-top: 1rem; }
  `,
})
export class Verification {
  private readonly http = inject(HttpClient);
  protected readonly session = inject(ServiceSession);

  /**
   * Le jeton, lu dans l'adresse.
   *
   * <p>Il vient de {@code withComponentInputBinding()} : le paramètre de
   * requête arrive directement en entrée du composant, sans lire
   * {@code ActivatedRoute} à la main.</p>
   *
   * <h2>⚠️ Le type dit {@code undefined}, et ce n'est pas une précaution</h2>
   *
   * <p>Écrit {@code input<string>('')}, ce champ vaut quand même
   * <b>{@code undefined}</b> quand l'adresse ne porte pas {@code ?jeton=} : le
   * routeur <b>affecte</b> l'entrée avec la valeur absente, et cette
   * affectation écrase la valeur par défaut. Celle-ci ne sert que si personne
   * n'affecte jamais l'entrée — ce qui n'arrive pas ici.</p>
   *
   * <p>Le premier jet lisait {@code this.jeton().trim()} : la page entière
   * restait <b>blanche</b>, sur un {@code TypeError} qu'aucun écran ne
   * montrait. Angular avait bien créé la balise ; son contenu, lui, n'existait
   * pas — pas même le texte statique, puisque le gabarit lève avant de
   * l'écrire.</p>
   */
  readonly jeton = input<string | undefined>('');

  protected readonly etat = signal<Etat>('attente');
  protected readonly message = signal('');

  protected readonly renvoi = signal(false);
  protected readonly renvoye = signal(false);
  protected readonly echecRenvoi = signal<string | null>(null);

  /** ⚠️ Un seul endroit lit l'entrée, et il la rend TOUJOURS sûre. */
  private valeurDuJeton(): string {
    return (this.jeton() ?? '').trim();
  }

  protected readonly aUnJeton = computed(() => this.valeurDuJeton().length > 0);

  constructor() {
    // ⚠️ Un `effect` et non le constructeur : l'entrée n'est pas encore
    //    renseignée à la construction. La lire là donnerait « lien incomplet »
    //    sur un lien parfaitement valide.
    effect(() => {
      if (this.aUnJeton()) {
        this.confirmer();
      } else {
        this.etat.set('sansJeton');
      }
    });
  }

  protected confirmer(): void {
    this.etat.set('attente');

    this.http
      .post<{ confirme: boolean }>('/api/auth/verification', { jeton: this.valeurDuJeton() })
      .subscribe({
        next: () => this.etat.set('confirme'),
        error: (e: unknown) => {
          // 410 : expiré, déjà utilisé, ou inconnu. Le serveur rend le MÊME
          // message dans les trois cas — distinguer renseignerait sur ce qui
          // a été émis, et la conduite à tenir est identique.
          const perime = typeof e === 'object' && e !== null && 'status' in e
            && (e as { status: number }).status === 410;

          this.message.set(
            messageErreur(e, 'La confirmation n’a pas pu aboutir. Réessayez.'),
          );
          this.etat.set(perime ? 'perime' : 'echec');
        },
      });
  }

  protected renvoyer(): void {
    if (this.renvoi()) {
      return;
    }
    this.renvoi.set(true);
    this.echecRenvoi.set(null);

    this.http.post<void>('/api/auth/verification/renvoi', {}).subscribe({
      next: () => {
        this.renvoi.set(false);
        this.renvoye.set(true);
      },
      error: (e: unknown) => {
        this.renvoi.set(false);
        this.echecRenvoi.set(
          messageErreur(e, 'Le lien n’a pas pu être renvoyé. Réessayez.'),
        );
      },
    });
  }
}
