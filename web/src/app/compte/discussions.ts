import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';

import { Page } from '../../modeles/catalogue';
import { RetourCompte } from './retour-compte';

interface VueConversation {
  readonly id: number;
  readonly sujet: string;
  readonly statut: string;
  readonly dateCreation: string;
  readonly dateCloture: string | null;
  /** L'Assistance GARAH : épinglée en tête, jamais close. */
  readonly assistance: boolean;
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
  imports: [FormsModule, RouterLink, RetourCompte],
  template: `
    <gb-retour-compte />

    <header class="entete">
      <h1>Mes discussions</h1>
      <p class="entete__aide">Questions, négociations, suivi d’un problème.</p>
    </header>

    <!-- 🎯 L'ASSISTANCE GARAH, ÉPINGLÉE EN TÊTE.
         Jusqu'ici une discussion ne naissait que du bouton « Contacter » d'une
         fiche produit : pour une question sur une livraison, un paiement, un
         compte, il n'y avait pas de porte. Celle-ci est toujours là, et c'est
         aussi par elle que GARAH vous écrit.

         ⚠️ Elle NAÎT DU PREMIER MESSAGE, pas d'un clic : tant qu'elle
            n'existe pas, la carte ouvre une zone de saisie. Créée à la simple
            ouverture, elle laisserait un dossier vide chez l'équipe. -->
    @if (!chargement() && !erreur()) {
      <section class="assistance">
        @if (assistance(); as a) {
          <a class="gb-carte gb-cliquable assistance__carte" [routerLink]="['/mes-discussions', a.id]">
            <svg class="assistance__icone" viewBox="0 0 24 24" fill="none" aria-hidden="true">
            <path d="M5 5h14v10H9.5L5 19V5Z" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round" />
            <path d="M8.5 9h7M8.5 12h4.5" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" />
          </svg>
            <span class="assistance__texte">
              <span class="assistance__titre">Assistance GARAH</span>
              <span class="assistance__aide">{{ etatAssistance(a.statut) }}</span>
            </span>
            <svg class="assistance__fleche" viewBox="0 0 24 24" fill="none" aria-hidden="true">
            <path d="m9 6 6 6-6 6" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" />
          </svg>
          </a>
        } @else if (redactionAssistance()) {
          <div class="gb-carte assistance__redaction">
            <p class="assistance__titre">Assistance GARAH</p>
            <textarea class="gb-champ zone" rows="4" maxlength="5000"
                      aria-label="Votre message à l’Assistance GARAH"
                      placeholder="Votre question, sur une commande, un paiement, votre compte…"
                      [ngModel]="messageAssistance()"
                      (ngModelChange)="messageAssistance.set($event)"></textarea>
            @if (echecAssistance(); as e) { <p class="gb-alerte">{{ e }}</p> }
            <div class="boutons">
              <button type="button" class="gb-btn gb-btn--secondaire" (click)="annulerAssistance()">
                Annuler
              </button>
              <button type="button" class="gb-btn gb-btn--primaire"
                      [disabled]="messageAssistance().trim().length === 0 || envoiAssistance()"
                      (click)="envoyerAssistance()">
                @if (envoiAssistance()) { Envoi… } @else { Envoyer }
              </button>
            </div>
          </div>
        } @else {
          <button type="button" class="gb-carte gb-cliquable assistance__carte"
                  (click)="redactionAssistance.set(true)">
            <svg class="assistance__icone" viewBox="0 0 24 24" fill="none" aria-hidden="true">
            <path d="M5 5h14v10H9.5L5 19V5Z" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round" />
            <path d="M8.5 9h7M8.5 12h4.5" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" />
          </svg>
            <span class="assistance__texte">
              <span class="assistance__titre">Assistance GARAH</span>
              <span class="assistance__aide">Une question ? Écrivez-nous, à tout moment.</span>
            </span>
            <svg class="assistance__fleche" viewBox="0 0 24 24" fill="none" aria-hidden="true">
            <path d="m9 6 6 6-6 6" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" />
          </svg>
          </button>
        }
      </section>
    }


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
    } @else if (autres().length === 0) {
      <p class="gb-etat gb-attenue">
        @if (assistance()) { Aucune autre discussion pour le moment. }
        @else { Vous n’avez aucune discussion en cours. }
      </p>
    } @else {
      <div class="liste">
        @for (c of autres(); track c.id) {
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

    .assistance { padding: 1.25rem 1.25rem 0; }

    .assistance__carte {
      width: 100%;
      display: flex;
      align-items: center;
      gap: 0.9rem;
      padding: 1rem;
      border: 1px solid color-mix(in srgb, var(--primaire) 30%, transparent);
      background: color-mix(in srgb, var(--primaire) 6%, var(--surface));
      color: inherit;
      font: inherit;
      text-align: left;
      text-decoration: none;
      cursor: pointer;
    }

    /* ⚠️ --primaire-texte et non --primaire : l'indigo de la charte tombe sous
       4,5:1 sur ce fond teinté, dans un thème comme dans l'autre. */
    .assistance__icone { width: 26px; height: 26px; flex-shrink: 0; color: var(--primaire-texte); }
    .assistance__texte { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 0.15rem; }
    .assistance__titre { margin: 0; font-size: 0.95rem; font-weight: 700; }
    .assistance__aide { font-size: 0.8rem; color: var(--texte-attenue); }
    .assistance__fleche { width: 16px; height: 16px; flex-shrink: 0; color: var(--texte-attenue); }
    .assistance__redaction { padding: 1rem; display: flex; flex-direction: column; gap: 0.75rem; }

    @media (min-width: 900px) {
      .entete, .actions, .liste, .assistance { padding-left: 0; padding-right: 0; }
      .assistance { max-width: 44rem; }
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

  private readonly router = inject(Router);

  /** L'Assistance GARAH, si elle existe déjà : elle naît du premier message. */
  protected readonly assistance = computed(
    () => this.conversations().find((c) => c.assistance) ?? null,
  );

  /** Les autres discussions : l'Assistance est épinglée au-dessus, pas répétée. */
  protected readonly autres = computed(() => this.conversations().filter((c) => !c.assistance));

  protected readonly redactionAssistance = signal(false);
  protected readonly messageAssistance = signal('');
  protected readonly envoiAssistance = signal(false);
  protected readonly echecAssistance = signal<string | null>(null);

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

  /** Ce que la carte épinglée dit de l'Assistance, selon son état. */
  protected etatAssistance(statut: string): string {
    if (statut === 'WAITING' || statut === 'ASSIGNED') {
      return this.libelle(statut);
    }
    return 'Une question ? Écrivez-nous, à tout moment.';
  }

  protected annulerAssistance(): void {
    this.redactionAssistance.set(false);
    this.messageAssistance.set('');
    this.echecAssistance.set(null);
  }

  /** Le premier message : il crée l'Assistance, puis on ouvre son fil. */
  protected envoyerAssistance(): void {
    const contenu = this.messageAssistance().trim();
    if (!contenu || this.envoiAssistance()) {
      return;
    }
    this.envoiAssistance.set(true);
    this.echecAssistance.set(null);

    this.http
      .post<{ conversationId: number }>('/api/conversations/assistance/messages', { contenu })
      .subscribe({
        next: (m) => {
          this.envoiAssistance.set(false);
          void this.router.navigate(['/mes-discussions', m.conversationId]);
        },
        error: (e: unknown) => {
          this.envoiAssistance.set(false);
          // Le texte reste dans le champ : le perdre ferait tout réécrire.
          this.echecAssistance.set(
            e instanceof HttpErrorResponse && e.status === 0
              ? 'Pas de connexion. Votre texte est conservé : réessayez.'
              : 'Votre message n’a pas pu partir.',
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
