import { HttpClient } from '@angular/common/http';
import { Component, inject, input, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { messageErreur } from '../../api/erreurs';

/**
 * ⚠️ DIX, et c'est le serveur qui décide.
 *
 * <p>L'écran acceptait huit caractères là où l'API en exige dix. Le visiteur
 * remplissait tout, cliquait, et recevait « Certains champs sont invalides » —
 * une phrase qui ne dit ni lequel ni pourquoi. Beaucoup s'arrêtaient là.</p>
 *
 * <p>Une constante nommée plutôt qu'un 10 posé dans le code : la valeur
 * apparaît à trois endroits de cet écran, et trois 8 recopiés sont exactement
 * ce qui a produit le défaut.</p>
 */
const LONGUEUR_MOT_DE_PASSE_MIN = 10;

/**
 * La création de compte.
 *
 * <p>⚠️ <b>L'inscription ne connecte pas.</b> Le serveur envoie un lien de
 * confirmation, et le compte n'est utilisable qu'une fois l'adresse vérifiée.
 * Rediriger vers la boutique comme si tout était fait ferait buter le client
 * au paiement, sans qu'il comprenne pourquoi.</p>
 *
 * <p>On affiche donc un écran d'attente explicite — et on nomme l'adresse, la
 * faute de frappe étant la première cause de « je n'ai rien reçu ».</p>
 */
@Component({
  selector: 'gb-inscription',
  imports: [FormsModule, RouterLink],
  template: `
    @if (envoye()) {
      <div class="confirme">
        <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
          <circle cx="12" cy="12" r="9" stroke="var(--succes)" stroke-width="1.6" />
          <path d="m8 12 3 3 5-6" stroke="var(--succes)" stroke-width="1.9"
                stroke-linecap="round" stroke-linejoin="round" />
        </svg>
        <h1>Vérifiez votre boîte mail</h1>
        <p>
          Un lien de confirmation est parti vers <strong>{{ email() }}</strong>.
          Votre compte sera utilisable dès que vous l’aurez ouvert.
        </p>
        <p class="confirme__aide">
          Rien reçu ? Regardez dans les indésirables, et vérifiez l’adresse
          ci-dessus.
        </p>
        <a routerLink="/connexion" class="gb-btn gb-btn--secondaire">Retour à la connexion</a>
      </div>
    } @else {
      <header class="entete">
        <h1>Créer un compte</h1>
        <p class="entete__aide">Il faut un compte pour commander, pas pour regarder.</p>
      </header>

      <form class="formulaire" (ngSubmit)="valider()" novalidate>
        <label class="gb-libelle" for="nom">Nom</label>
        <input id="nom" name="nom" class="gb-champ" required autocomplete="name"
               [ngModel]="nom()" (ngModelChange)="nom.set($event)" />

        <label class="gb-libelle" for="email">Adresse e-mail</label>
        <input id="email" name="email" type="email" class="gb-champ" required
               autocomplete="email" inputmode="email"
               [ngModel]="email()" (ngModelChange)="email.set($event)" />

        <label class="gb-libelle" for="tel">Téléphone</label>
        <input id="tel" name="telephone" class="gb-champ" autocomplete="tel" inputmode="tel"
               placeholder="+237 6 99 00 00 00"
               [ngModel]="telephone()" (ngModelChange)="telephone.set($event)" />

        <label class="gb-libelle" for="mdp">Mot de passe</label>
        <input id="mdp" name="motDePasse" type="password" class="gb-champ" required
               autocomplete="new-password"
               [ngModel]="motDePasse()" (ngModelChange)="motDePasse.set($event)" />
        <p class="aide">Au moins 10 caractères. Une phrase vaut mieux qu’un mot compliqué.</p>

        @if (erreur(); as m) {
          <p class="gb-alerte" role="alert">{{ m }}</p>
        } @else if (manque(); as m) {
          <!-- 🎯 Ce qui manque, DIT AVANT le clic. Un bouton grisé sans
               explication fait chercher la panne dans la connexion. -->
          <p class="manque">{{ m }}</p>
        }

        <button type="submit" class="gb-btn gb-btn--primaire gb-btn--plein"
                [disabled]="!complet() || envoi()">
          @if (envoi()) { Création… } @else { Créer mon compte }
        </button>
      </form>

      <p class="bascule">
        Déjà un compte ?
        <a routerLink="/connexion" [queryParams]="{ suite: suite() }">Se connecter</a>
      </p>
    }
  `,
  styles: `
    .entete { padding: 1.5rem 1.25rem 1rem; }
    .entete h1 { margin: 0; font-size: 1.3rem; font-weight: 700; }
    .entete__aide { margin: 0.35rem 0 0; font-size: 0.82rem; color: var(--texte-attenue); }

    .formulaire { padding: 0 1.25rem; display: flex; flex-direction: column; gap: 0.35rem; }
    .formulaire .gb-libelle:not(:first-child) { margin-top: 0.9rem; }
    .formulaire .gb-btn { margin-top: 1.4rem; }
    .formulaire .gb-alerte { margin-top: 1rem; }

    .aide { margin: 0.3rem 0 0; font-size: 0.75rem; color: var(--texte-attenue); }

    /* Ce qui manque est de l'AIDE, pas une erreur : ambre et non rouge. Le
       rouge dit « vous avez fait une faute » à quelqu'un qui est simplement en
       train de remplir le formulaire. */
    .manque { margin: 1rem 0 0; font-size: 0.8rem; color: var(--alerte); }

    .bascule {
      padding: 1.25rem;
      text-align: center;
      font-size: 0.85rem;
      color: var(--texte-attenue);

      a { color: var(--primaire); font-weight: 600; text-decoration: none; }
    }

    .confirme {
      padding: 3rem 1.5rem;
      text-align: center;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 0.75rem;

      svg { width: 52px; height: 52px; }
      h1 { margin: 0.5rem 0 0; font-size: 1.2rem; font-weight: 700; }
      p { margin: 0; font-size: 0.875rem; line-height: 1.6; }
      .gb-btn { margin-top: 1rem; }
    }

    .confirme__aide { color: var(--texte-attenue); font-size: 0.8rem !important; }
  `,
})
export class Inscription {
  private readonly http = inject(HttpClient);

  readonly suite = input<string>('/');

  protected readonly nom = signal('');
  protected readonly email = signal('');
  protected readonly telephone = signal('');
  protected readonly motDePasse = signal('');

  protected readonly envoi = signal(false);
  protected readonly envoye = signal(false);
  protected readonly erreur = signal<string | null>(null);

  protected complet(): boolean {
    return (
      this.nom().trim().length > 0 &&
      this.email().trim().length > 0 &&
      this.motDePasse().length >= LONGUEUR_MOT_DE_PASSE_MIN
    );
  }

  /**
   * Ce qui manque encore, en une phrase.
   *
   * <p>🎯 Dire ce qui manque AVANT le clic. Un bouton grisé sans raison fait
   * chercher la panne ailleurs — souvent dans la connexion.</p>
   */
  protected manque(): string | null {
    if (this.nom().trim().length === 0) {
      return 'Votre nom est nécessaire.';
    }
    if (!this.email().includes('@')) {
      return 'Entrez une adresse e-mail valide.';
    }
    if (this.motDePasse().length > 0
        && this.motDePasse().length < LONGUEUR_MOT_DE_PASSE_MIN) {
      return `Il manque ${LONGUEUR_MOT_DE_PASSE_MIN - this.motDePasse().length} caractère(s) au mot de passe.`;
    }
    if (this.motDePasse().length === 0) {
      return 'Choisissez un mot de passe.';
    }
    return null;
  }

  protected valider(): void {
    if (!this.complet() || this.envoi()) {
      return;
    }
    this.envoi.set(true);
    this.erreur.set(null);

    this.http
      .post('/api/auth/inscription', {
        nom: this.nom().trim(),
        email: this.email().trim(),
        telephone: this.telephone().trim() || null,
        motDePasse: this.motDePasse(),
      })
      .subscribe({
        next: () => {
          this.envoi.set(false);
          this.envoye.set(true);
        },
        error: (e: unknown) => {
          this.envoi.set(false);
          this.erreur.set(messageErreur(e, 'Le compte n’a pas pu être créé.'));
        },
      });
  }
}

