import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';

import { Page } from '../../modeles/catalogue';
import { MenuCompte } from './menu-compte';

interface VueReclamation {
  readonly id: number;
  readonly numero: string;
  readonly commandeId: number;
  readonly motif: string;
  readonly description: string;
  readonly statut: string;
  readonly dateCreation: string;
  readonly dateResolution: string | null;
}

interface ResumeCommande {
  readonly id: number;
  readonly numero: string;
  readonly statut: string;
  readonly dateCreation: string;
}

const LIBELLES: Record<string, { texte: string; classe: string }> = {
  OUVERTE: { texte: 'Reçue', classe: 'gb-etiquette--alerte' },
  EN_COURS: { texte: 'En cours d’examen', classe: 'gb-etiquette--info' },
  RESOLUE: { texte: 'Résolue', classe: 'gb-etiquette--succes' },
  FERMEE: { texte: 'Close', classe: 'gb-etiquette--neutre' },
};

/**
 * Mes réclamations — la voie de recours.
 *
 * <h2>⚠️ Ouvrir une réclamation ne rembourse rien et ne promet rien</h2>
 *
 * <p>L'écran doit le dire, et le dire <b>avant</b> l'envoi. Un formulaire qui
 * se contente d'un « demande enregistrée » laisse attendre un virement qui ne
 * viendra pas ; l'attente se transforme alors en seconde réclamation, puis en
 * appel téléphonique. C'est un humain qui examine, et ça se voit à l'écran.</p>
 *
 * <h2>La commande se CHOISIT dans une liste</h2>
 *
 * <p>Jamais un numéro à recopier. Le système connaît les commandes du client :
 * les lui faire saisir n'ajoute aucune information et ouvre la porte à une
 * faute de frappe qui rattache le dossier à la commande d'un autre.</p>
 */
@Component({
  selector: 'gb-reclamations',
  imports: [FormsModule, RouterLink, MenuCompte],
  template: `
    <header class="entete">
      <h1>Mes réclamations</h1>
      <p class="entete__aide">Un conseiller examine chaque dossier.</p>
    </header>

    <gb-menu-compte />

    @if (ouverture()) {
      <section class="gb-carte formulaire">
        <p class="gb-libelle">Nouvelle réclamation</p>

        @if (commandes().length === 0) {
          <p class="gb-attenue vide">
            Une réclamation porte sur une commande. Vous n’en avez pas encore.
          </p>
        } @else {
          <label class="champ">
            <span class="gb-libelle">Commande concernée</span>
            <select class="gb-champ" [ngModel]="commandeId()" (ngModelChange)="commandeId.set($event)"
                    name="commande" aria-label="Commande concernée">
              @for (c of commandes(); track c.id) {
                <option [value]="c.id">{{ c.numero }} — {{ date(c.dateCreation) }}</option>
              }
            </select>
          </label>

          <label class="champ">
            <span class="gb-libelle">En un mot</span>
            <input type="text" class="gb-champ" name="motif" maxlength="200"
                   placeholder="Article manquant, article abîmé…"
                   [ngModel]="motif()" (ngModelChange)="motif.set($event)" />
          </label>

          <label class="champ">
            <span class="gb-libelle">Ce qui s’est passé</span>
            <textarea class="gb-champ zone" name="description" rows="5" maxlength="5000"
                      placeholder="Décrivez le problème le plus précisément possible."
                      [ngModel]="description()" (ngModelChange)="description.set($event)"></textarea>
          </label>

          <!-- 🎯 Dire ce qui manque AVANT le clic, jamais après. Un bouton
               désactivé sans explication passe pour une panne. -->
          @if (manque(); as m) {
            <p class="manque">{{ m }}</p>
          }

          @if (echec(); as e) {
            <p class="gb-alerte">{{ e }}</p>
          }

          <!-- Ce que l'ouverture fait, et ce qu'elle ne fait pas. -->
          <p class="prevenu">
            Ouvrir un dossier n’annule pas la commande et ne déclenche aucun
            remboursement : un conseiller l’examine et vous répond.
          </p>

          <div class="boutons">
            <button type="button" class="gb-btn gb-btn--secondaire" (click)="annuler()">
              Annuler
            </button>
            <button type="button" class="gb-btn gb-btn--primaire"
                    [disabled]="manque() !== null || envoi()" (click)="envoyer()">
              @if (envoi()) { Envoi… } @else { Envoyer }
            </button>
          </div>
        }
      </section>
    } @else {
      <div class="actions">
        <button type="button" class="gb-btn gb-btn--primaire" (click)="ouvrir()">
          Ouvrir une réclamation
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
    } @else if (reclamations().length === 0) {
      <p class="gb-etat gb-attenue">Vous n’avez ouvert aucune réclamation.</p>
    } @else {
      <div class="liste">
        @for (r of reclamations(); track r.id) {
          <article class="gb-carte dossier">
            <div class="dossier__tete">
              <p class="dossier__numero gb-mono">{{ r.numero }}</p>
              <span class="gb-etiquette" [class]="classe(r.statut)">{{ libelle(r.statut) }}</span>
            </div>
            <p class="dossier__motif">{{ r.motif }}</p>
            <p class="dossier__texte">{{ r.description }}</p>
            <p class="dossier__date">
              Ouverte le {{ date(r.dateCreation) }}@if (r.dateResolution) { · close le {{ date(r.dateResolution) }} }
            </p>
            <a [routerLink]="['/mes-commandes', r.commandeId]" class="dossier__lien">
              Voir la commande
            </a>
          </article>
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
    .vide { margin: 0; font-size: 0.85rem; }

    .manque { margin: 0; font-size: 0.8rem; color: var(--alerte); }

    .prevenu {
      margin: 0;
      padding: 0.7rem 0.85rem;
      border-radius: var(--rayon-petit);
      background: var(--surface-douce);
      font-size: 0.78rem;
      color: var(--texte-attenue);
      line-height: 1.55;
    }

    .boutons { display: flex; gap: 0.6rem; justify-content: flex-end; flex-wrap: wrap; }

    .liste { padding: 1.25rem; display: flex; flex-direction: column; gap: 0.85rem; }

    .dossier { padding: 1rem; display: flex; flex-direction: column; gap: 0.5rem; }

    .dossier__tete {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 0.75rem;
    }

    .dossier__numero { margin: 0; font-size: 0.85rem; font-weight: 700; }
    .dossier__motif { margin: 0; font-size: 0.92rem; font-weight: 600; }
    .dossier__texte { margin: 0; font-size: 0.84rem; color: var(--texte-attenue); line-height: 1.55; white-space: pre-line; }
    .dossier__date { margin: 0; font-size: 0.75rem; color: var(--texte-attenue); }

    .dossier__lien {
      min-height: var(--cible-tactile-min);
      display: inline-flex;
      align-items: center;
      align-self: flex-start;
      font-size: 0.83rem;
      font-weight: 600;
      color: var(--primaire);
      text-decoration: none;
    }

    @media (hover: hover) {
      .dossier__lien:hover { text-decoration: underline; }
    }

    @media (min-width: 900px) {
      .entete, .actions, .liste { padding-left: 0; padding-right: 0; }
      .formulaire { margin-left: 0; margin-right: 0; max-width: 44rem; }
      .liste { max-width: 44rem; }
    }
  `,
})
export class Reclamations {
  private readonly http = inject(HttpClient);

  protected readonly reclamations = signal<readonly VueReclamation[]>([]);
  protected readonly commandes = signal<readonly ResumeCommande[]>([]);
  protected readonly chargement = signal(true);
  protected readonly erreur = signal<string | null>(null);

  protected readonly ouverture = signal(false);
  protected readonly commandeId = signal<string>('');
  protected readonly motif = signal('');
  protected readonly description = signal('');
  protected readonly envoi = signal(false);
  protected readonly echec = signal<string | null>(null);

  /**
   * Ce qui manque encore, en une phrase.
   *
   * <p>🎯 Dire ce qui manque <b>avant</b> le clic. Un bouton grisé sans raison
   * fait chercher la panne ailleurs — souvent dans la connexion.</p>
   */
  protected readonly manque = computed<string | null>(() => {
    if (!this.commandeId()) {
      return 'Choisissez la commande concernée.';
    }
    if (this.motif().trim().length < 3) {
      return 'Résumez le problème en quelques mots.';
    }
    if (this.description().trim().length < 10) {
      return 'Décrivez ce qui s’est passé, en une phrase au moins.';
    }
    return null;
  });

  constructor() {
    queueMicrotask(() => this.charger());
  }

  protected charger(): void {
    this.chargement.set(true);
    this.erreur.set(null);

    this.http.get<Page<VueReclamation>>('/api/sav/reclamations/miennes?taille=50').subscribe({
      next: (p) => {
        this.reclamations.set(p.content);
        this.chargement.set(false);
      },
      error: (e: unknown) => {
        this.chargement.set(false);
        this.erreur.set(
          e instanceof HttpErrorResponse && e.status === 0
            ? 'Pas de connexion. Réessayez dans un instant.'
            : 'Vos réclamations n’ont pas pu être chargées.',
        );
      },
    });

    // Les commandes servent le formulaire, pas la liste : leur échec ne doit
    // donc pas vider l'écran.
    this.http.get<Page<ResumeCommande>>('/api/commandes/miennes?taille=50').subscribe({
      next: (p) => this.commandes.set(p.content),
      error: () => this.commandes.set([]),
    });
  }

  protected ouvrir(): void {
    this.ouverture.set(true);
    this.echec.set(null);
    // La commande la plus récente d'abord : c'est presque toujours celle qui
    // pose problème, et un choix déjà fait évite une manipulation.
    this.commandeId.set(this.commandes()[0] ? String(this.commandes()[0].id) : '');
  }

  protected annuler(): void {
    this.ouverture.set(false);
    this.motif.set('');
    this.description.set('');
    this.echec.set(null);
  }

  protected envoyer(): void {
    if (this.manque() !== null || this.envoi()) {
      return;
    }
    this.envoi.set(true);
    this.echec.set(null);

    this.http
      .post<VueReclamation>('/api/sav/reclamations', {
        commandeId: Number(this.commandeId()),
        motif: this.motif().trim(),
        description: this.description().trim(),
      })
      .subscribe({
        next: (r) => {
          this.envoi.set(false);
          // En tête : le dossier qu'on vient d'ouvrir est celui qu'on cherche
          // des yeux juste après avoir cliqué.
          this.reclamations.update((l) => [r, ...l]);
          this.annuler();
        },
        error: (e: unknown) => {
          this.envoi.set(false);
          this.echec.set(
            e instanceof HttpErrorResponse && e.status === 0
              ? 'Pas de connexion. Votre texte est conservé : réessayez.'
              : 'La réclamation n’a pas pu être envoyée.',
          );
        },
      });
  }

  // -------------------------------------------------------------------------

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
