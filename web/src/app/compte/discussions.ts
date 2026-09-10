import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';

import { Page } from '../../modeles/catalogue';
import { MenuCompte } from './menu-compte';

interface VueConversation {
  readonly id: number;
  readonly sujet: string;
  readonly statut: string;
  readonly dateCreation: string;
  readonly dateCloture: string | null;
}

const LIBELLES: Record<string, { texte: string; classe: string }> = {
  // ⚠️ Les codes du serveur sont en anglais ; l'écran, lui, parle français.
  //    Les afficher tels quels apprendrait au client un vocabulaire interne
  //    qui n'est pas le sien.
  // Ouverte par GARAH pour vous prevenir (un colis parti). Personne n'attend
  // de reponse — mais vous pouvez en ecrire une, et un conseiller la lira.
  INFORMATION: { texte: 'Information', classe: 'gb-etiquette--info' },
  WAITING: { texte: 'En attente d’un conseiller', classe: 'gb-etiquette--alerte' },
  ASSIGNED: { texte: 'Un conseiller vous suit', classe: 'gb-etiquette--info' },
  CLOSED: { texte: 'Close', classe: 'gb-etiquette--neutre' },
};

/**
 * Mes discussions.
 *
 * <p>🎯 Sans cette liste, une conversation ouverte était <b>perdue au premier
 * rechargement</b> : il fallait garder l'onglet. Une négociation qui dure deux
 * jours — c'est-à-dire la plupart — n'était donc pas praticable.</p>
 */
@Component({
  selector: 'gb-discussions',
  imports: [FormsModule, RouterLink, MenuCompte],
  template: `
    <header class="entete">
      <h1>Mes discussions</h1>
      <p class="entete__aide">Questions, négociations, suivi d’un problème.</p>
    </header>

    <gb-menu-compte />

    @if (ouverture()) {
      <section class="gb-carte formulaire">
        <p class="gb-libelle">Nouvelle discussion</p>

        <label class="champ">
          <span class="gb-libelle">Sujet</span>
          <input type="text" class="gb-champ" name="sujet" maxlength="200"
                 placeholder="Négocier un prix, poser une question…"
                 [ngModel]="sujet()" (ngModelChange)="sujet.set($event)" />
        </label>

        <label class="champ">
          <span class="gb-libelle">Votre message</span>
          <textarea class="gb-champ zone" name="message" rows="5" maxlength="5000"
                    [ngModel]="message()" (ngModelChange)="message.set($event)"></textarea>
        </label>

        @if (manque(); as m) { <p class="manque">{{ m }}</p> }
        @if (echec(); as e) { <p class="gb-alerte">{{ e }}</p> }

        <div class="boutons">
          <button type="button" class="gb-btn gb-btn--secondaire" (click)="annuler()">Annuler</button>
          <button type="button" class="gb-btn gb-btn--primaire"
                  [disabled]="manque() !== null || envoi()" (click)="envoyer()">
            @if (envoi()) { Envoi… } @else { Envoyer }
          </button>
        </div>
      </section>
    } @else {
      <div class="actions">
        <button type="button" class="gb-btn gb-btn--primaire" (click)="ouvrir()">
          Démarrer une discussion
        </button>
      </div>
    }

    @if (erreur(); as m) {
      <div class="gb-etat">
        <p>{{ m }}</p>
        <button type="button" class="gb-btn gb-btn--secondaire" (click)="charger()">Réessayer</button>
      </div>
    } @else if (chargement()) {
      <div class="gb-etat"><p>Chargement…</p></div>
    } @else if (conversations().length === 0) {
      <p class="gb-etat gb-attenue">Vous n’avez aucune discussion en cours.</p>
    } @else {
      <div class="liste">
        @for (c of conversations(); track c.id) {
          <a class="gb-carte gb-cliquable fil" [routerLink]="['/mes-discussions', c.id]">
            <div class="fil__tete">
              <p class="fil__sujet">{{ c.sujet }}</p>
              <span class="gb-etiquette" [class]="classe(c.statut)">{{ libelle(c.statut) }}</span>
            </div>
            <p class="fil__date">Ouverte le {{ date(c.dateCreation) }}</p>
          </a>
        }
      </div>
    }
  `,
  styles: `
    .entete { padding: 1.5rem 1.25rem 0.25rem; }
    .entete h1 { margin: 0; font-size: 1.3rem; font-weight: 700; }
    .entete__aide { margin: 0.25rem 0 0; font-size: 0.82rem; color: var(--texte-attenue); }

    .actions { padding: 1.25rem 1.25rem 0; }

    .formulaire {
      margin: 1.25rem;
      padding: 1.25rem;
      display: flex;
      flex-direction: column;
      gap: 0.9rem;
    }

    .champ { display: block; }
    .zone { min-height: 7rem; resize: vertical; line-height: 1.5; }
    .manque { margin: 0; font-size: 0.8rem; color: var(--alerte); }
    .boutons { display: flex; gap: 0.6rem; justify-content: flex-end; flex-wrap: wrap; }

    .liste { padding: 1.25rem; display: flex; flex-direction: column; gap: 0.75rem; }

    .fil {
      padding: 1rem;
      display: flex;
      flex-direction: column;
      gap: 0.4rem;
      color: inherit;
      text-decoration: none;
    }

    .fil__tete { display: flex; align-items: center; justify-content: space-between; gap: 0.75rem; }
    .fil__sujet { margin: 0; font-size: 0.92rem; font-weight: 600; }
    .fil__date { margin: 0; font-size: 0.75rem; color: var(--texte-attenue); }

    @media (min-width: 900px) {
      .entete, .actions, .liste { padding-left: 0; padding-right: 0; }
      .formulaire { margin-left: 0; margin-right: 0; max-width: 44rem; }
      .liste { max-width: 44rem; }
    }
  `,
})
export class Discussions {
  private readonly http = inject(HttpClient);

  protected readonly conversations = signal<readonly VueConversation[]>([]);
  protected readonly chargement = signal(true);
  protected readonly erreur = signal<string | null>(null);

  protected readonly ouverture = signal(false);
  protected readonly sujet = signal('');
  protected readonly message = signal('');
  protected readonly envoi = signal(false);
  protected readonly echec = signal<string | null>(null);

  protected readonly manque = computed<string | null>(() => {
    if (this.sujet().trim().length < 3) {
      return 'Donnez un sujet à votre discussion.';
    }
    if (this.message().trim().length < 5) {
      return 'Écrivez votre message.';
    }
    return null;
  });

  constructor() {
    queueMicrotask(() => this.charger());
  }

  protected charger(): void {
    this.chargement.set(true);
    this.erreur.set(null);

    this.http.get<Page<VueConversation>>('/api/conversations/miennes?taille=50').subscribe({
      next: (p) => {
        this.conversations.set(p.content);
        this.chargement.set(false);
      },
      error: (e: unknown) => {
        this.chargement.set(false);
        this.erreur.set(
          e instanceof HttpErrorResponse && e.status === 0
            ? 'Pas de connexion. Réessayez dans un instant.'
            : 'Vos discussions n’ont pas pu être chargées.',
        );
      },
    });
  }

  protected ouvrir(): void {
    this.ouverture.set(true);
    this.echec.set(null);
  }

  protected annuler(): void {
    this.ouverture.set(false);
    this.sujet.set('');
    this.message.set('');
    this.echec.set(null);
  }

  protected envoyer(): void {
    if (this.manque() !== null || this.envoi()) {
      return;
    }
    this.envoi.set(true);
    this.echec.set(null);

    this.http
      .post<VueConversation>('/api/conversations', {
        sujet: this.sujet().trim(),
        premierMessage: this.message().trim(),
      })
      .subscribe({
        next: (c) => {
          this.envoi.set(false);
          this.conversations.update((l) => [c, ...l]);
          this.annuler();
        },
        error: (e: unknown) => {
          this.envoi.set(false);
          this.echec.set(
            e instanceof HttpErrorResponse && e.status === 0
              ? 'Pas de connexion. Votre texte est conservé : réessayez.'
              : 'La discussion n’a pas pu être ouverte.',
          );
        },
      });
  }

  protected libelle(statut: string): string {
    return LIBELLES[statut]?.texte ?? statut;
  }

  protected classe(statut: string): string {
    return LIBELLES[statut]?.classe ?? 'gb-etiquette--neutre';
  }

  protected date(iso: string): string {
    return new Date(iso).toLocaleDateString('fr-FR', {
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    });
  }
}
