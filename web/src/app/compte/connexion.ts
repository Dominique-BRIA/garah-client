import { Component, inject, input, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';

import { PanierLocal } from '../../services/panier-local';
import { ServiceSession } from '../../services/session';

/**
 * La connexion.
 *
 * <p>🎯 C'est ici que le <b>panier local rejoint le serveur</b> : la session
 * appelle {@code POST /api/panier/fusion} juste après avoir posé le jeton.
 * Le visiteur qui a rempli son panier sans compte le retrouve donc intact.</p>
 *
 * <p>On revient <b>là où on allait</b>, jamais sur l'accueil : se retrouver
 * ailleurs qu'à sa destination fait recommencer toute la navigation.</p>
 */
@Component({
  selector: 'gb-connexion',
  imports: [FormsModule, RouterLink],
  template: `
    <header class="entete">
      <h1>Se connecter</h1>
      @if (panier.nombreArticles() > 0) {
        <!-- Rassurer AVANT le formulaire : un visiteur qui a rempli son panier
             craint de le perdre, et c'est le moment où il hésite. -->
        <p class="entete__aide">
          Vos {{ panier.nombreArticles() }} article(s) vous suivent.
        </p>
      }
    </header>

    <form class="formulaire" (ngSubmit)="valider()" novalidate>
      <label class="gb-libelle" for="email">Adresse e-mail</label>
      <input id="email" name="email" type="email" class="gb-champ" required
             autocomplete="email" inputmode="email"
             [ngModel]="email()" (ngModelChange)="email.set($event)" />

      <label class="gb-libelle" for="mdp">Mot de passe</label>
      <input id="mdp" name="motDePasse" type="password" class="gb-champ" required
             autocomplete="current-password"
             [ngModel]="motDePasse()" (ngModelChange)="motDePasse.set($event)" />

      @if (erreur(); as m) {
        <p class="gb-alerte" role="alert">{{ m }}</p>
      }

      <button type="submit" class="gb-btn gb-btn--primaire gb-btn--plein"
              [disabled]="!complet() || envoi()">
        @if (envoi()) { Connexion… } @else { Se connecter }
      </button>
    </form>

    <p class="bascule">
      Pas encore de compte ?
      <a routerLink="/inscription" [queryParams]="{ suite: suite() }">Créer un compte</a>
    </p>
  `,
  styles: `
    .entete { padding: 1.5rem 1.25rem 1rem; }
    .entete h1 { margin: 0; font-size: 1.3rem; font-weight: 700; }
    .entete__aide { margin: 0.35rem 0 0; font-size: 0.82rem; color: var(--texte-attenue); }

    .formulaire {
      padding: 0 1.25rem;
      display: flex;
      flex-direction: column;
      gap: 0.35rem;
    }

    .formulaire .gb-libelle:not(:first-child) { margin-top: 0.9rem; }
    .formulaire .gb-btn { margin-top: 1.4rem; }
    .formulaire .gb-alerte { margin-top: 1rem; }

    .bascule {
      padding: 1.25rem;
      text-align: center;
      font-size: 0.85rem;
      color: var(--texte-attenue);

      a { color: var(--primaire); font-weight: 600; text-decoration: none; }
    }
  `,
})
export class Connexion {
  private readonly session = inject(ServiceSession);
  private readonly router = inject(Router);
  protected readonly panier = inject(PanierLocal);

  /** Où retourner après la connexion. Posé par le garde. */
  readonly suite = input<string>('/');

  protected readonly email = signal('');
  protected readonly motDePasse = signal('');
  protected readonly envoi = signal(false);
  protected readonly erreur = signal<string | null>(null);

  protected complet(): boolean {
    return this.email().trim().length > 0 && this.motDePasse().length > 0;
  }

  protected valider(): void {
    if (!this.complet() || this.envoi()) {
      return;
    }
    this.envoi.set(true);
    this.erreur.set(null);

    this.session.connecter(this.email().trim(), this.motDePasse()).subscribe((ouverte) => {
      this.envoi.set(false);
      if (ouverte) {
        void this.router.navigateByUrl(this.suite() || '/');
      } else {
        // ⚠️ On ne dit PAS lequel des deux est faux. Distinguer « cette adresse
        //    n'existe pas » de « mot de passe incorrect » permet de deviner
        //    quels comptes existent.
        this.erreur.set('Adresse e-mail ou mot de passe incorrect.');
      }
    });
  }
}
