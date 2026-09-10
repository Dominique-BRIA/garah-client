import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Component, DestroyRef, computed, inject, input, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';

import { montantLisible } from '../../modeles/catalogue';
import { ServiceSession } from '../../services/session';
import { ServiceTempsReel } from '../../services/temps-reel';

/**
 * La file personnelle des messages de conversation.
 *
 * ⚠️ Le prefixe /utilisateur est resolu par le serveur vers la session de
 *    l abonne. Une destination partagee livrerait les discussions d un
 *    client a tous les autres connectes.
 */
const DESTINATION_CONVERSATIONS = '/utilisateur/file/conversations';

interface VueMessage {
  readonly id: number;
  /** Present sur le message pousse en temps reel comme sur celui du fil. */
  readonly conversationId: number;
  /*
   * ⚠️ NUL quand c'est GARAH qui ecrit — un colis parti, par exemple. Le
   * systeme n'est pas un utilisateur. Toute comparaison doit donc supporter
   * null, et c'est ce que fait deja `estMoi` : null n'est jamais moi.
   */
  readonly expediteurId: number | null;
  readonly contenu: string;
  readonly dateEnvoi: string;
}

interface VueConversation {
  readonly id: number;
  readonly clientId: number;
  readonly sujet: string;
  readonly statut: string;
  readonly dateCreation: string;
  readonly dateCloture: string | null;
  readonly messages: readonly VueMessage[];
}

interface VueProposition {
  readonly id: number;
  readonly varianteId: number;
  readonly quantite: number;
  readonly prixUnitairePropose: number;
  readonly auteurId: number;
  readonly sens: string;
  readonly statut: string;
  /** Calculé par le serveur : ni expirée, ni consommée, ni refusée. */
  readonly utilisable: boolean;
  readonly dateCreation: string;
  readonly dateExpiration: string | null;
}

const ETATS: Record<string, { texte: string; classe: string }> = {
  PROPOSEE: { texte: 'En attente', classe: 'gb-etiquette--alerte' },
  ACCEPTEE: { texte: 'Acceptée', classe: 'gb-etiquette--succes' },
  REFUSEE: { texte: 'Refusée', classe: 'gb-etiquette--neutre' },
  EXPIREE: { texte: 'Expirée', classe: 'gb-etiquette--neutre' },
  CONSOMMEE: { texte: 'Utilisée', classe: 'gb-etiquette--info' },
};

/**
 * Le fil d'une discussion, propositions comprises.
 *
 * <h2>🎯 La négociation n'est pas une messagerie</h2>
 *
 * <p>Un prix proposé n'est pas une phrase dans un fil : c'est un
 * <b>engagement daté</b>, qui expire et qu'on accepte d'un geste. Le mélanger
 * au texte obligerait à relire toute la conversation pour savoir où l'on en
 * est — et deux personnes n'y liraient pas le même chiffre.</p>
 *
 * <h2>⚠️ « Utilisable » vient du SERVEUR, jamais d'un calcul d'ici</h2>
 *
 * <p>La règle est « ni expirée, ni consommée, ni refusée ». Trois applications
 * qui la réimplémenteraient finiraient par diverger, et l'une d'elles
 * afficherait « Accepter » sur une proposition morte. Le champ est calculé
 * côté serveur, l'écran ne fait que le lire.</p>
 *
 * <h2>Le sens ne se choisit pas</h2>
 *
 * <p>Il est déduit du jeton. Un client qui pourrait écrire
 * {@code sens: "RESPONSABLE"} s'accorderait n'importe quelle remise — c'est
 * pourquoi l'écran n'a aucun champ pour cela, et n'en aura jamais.</p>
 */
@Component({
  selector: 'gb-discussion',
  imports: [FormsModule, RouterLink],
  template: `
    @if (erreur(); as m) {
      <div class="gb-etat">
        <p>{{ m }}</p>
        <a routerLink="/mes-discussions" class="gb-btn gb-btn--secondaire">Mes discussions</a>
      </div>
    } @else if (chargement()) {
      <div class="gb-etat"><p>Chargement…</p></div>
    } @else if (conversation(); as c) {
      <header class="entete">
        <a routerLink="/mes-discussions" class="entete__retour">Mes discussions</a>
        <div class="entete__ligne">
          <h1>{{ c.sujet }}</h1>
          <span class="gb-etiquette" [class]="classeFil(c.statut)">{{ libelleFil(c.statut) }}</span>
        </div>
      </header>

      <!-- ================================================================ -->
      <!-- LES PROPOSITIONS — au-dessus du fil, et séparées de lui           -->
      <!-- ================================================================ -->
      @if (propositions().length > 0) {
        <section class="propositions">
          <p class="gb-libelle">Prix proposés</p>
          @for (p of propositions(); track p.id) {
            <article class="gb-carte offre" [class.offre--vive]="p.utilisable">
              <div class="offre__tete">
                <div>
                  <p class="offre__prix gb-montant">{{ montant(p.prixUnitairePropose) }}</p>
                  <p class="offre__detail">
                    l’unité · {{ p.quantite }} pièce(s) ·
                    {{ p.sens === 'CLIENT' ? 'votre offre' : 'proposition du vendeur' }}
                  </p>
                </div>
                <span class="gb-etiquette" [class]="classeOffre(p.statut)">{{ libelleOffre(p.statut) }}</span>
              </div>

              @if (p.dateExpiration && p.utilisable) {
                <p class="offre__delai">Valable jusqu’au {{ dateHeure(p.dateExpiration) }}</p>
              }

              <!-- ⚠️ On ne répond qu'à une offre du VENDEUR. Proposer
                   « accepter » sur sa propre offre n'aurait aucun sens, et
                   « refuser » la sienne non plus. -->
              @if (p.utilisable && p.sens === 'RESPONSABLE') {
                <div class="offre__boutons">
                  <button type="button" class="gb-btn gb-btn--secondaire"
                          [disabled]="action()" (click)="refuser(p)">
                    Refuser
                  </button>
                  <button type="button" class="gb-btn gb-btn--primaire"
                          [disabled]="action()" (click)="accepter(p)">
                    Accepter ce prix
                  </button>
                </div>

                <div class="contre">
                  <input type="number" class="gb-champ contre__champ" min="1" step="1"
                         [name]="'contre-' + p.id" placeholder="Votre contre-offre"
                         aria-label="Votre contre-offre, à l’unité"
                         [ngModel]="contre()" (ngModelChange)="contre.set($event)" />
                  <button type="button" class="gb-btn gb-btn--secondaire"
                          [disabled]="!contreValide() || action()" (click)="contreProposer(p)">
                    Contre-proposer
                  </button>
                </div>
              }
            </article>
          }
        </section>
      }

      <section class="fil">
        <p class="gb-libelle">Échanges</p>
        @for (m of c.messages; track m.id) {
          <div class="bulle" [class.bulle--moi]="estMoi(m)">
            @if (m.expediteurId === null) {
              <!-- Dire QUI parle : sans ce nom, une annonce se lirait comme la
                   reponse d'un conseiller, et on lui repondrait en attendant
                   quelqu'un qui n'a rien ecrit. -->
              <p class="bulle__auteur">GARAH</p>
            }
            <p class="bulle__texte">{{ m.contenu }}</p>
            <p class="bulle__date">{{ dateHeure(m.dateEnvoi) }}</p>
          </div>
        }
      </section>

      @if (c.statut === 'CLOSED') {
        <p class="close">
          Cette discussion est close. Ouvrez-en une nouvelle si le sujet
          revient.
        </p>
      } @else {
        <div class="reponse">
          <textarea class="gb-champ zone" name="reponse" rows="3" maxlength="5000"
                    placeholder="Votre message…" aria-label="Votre message"
                    [ngModel]="texte()" (ngModelChange)="texte.set($event)"></textarea>
          @if (echec(); as e) { <p class="gb-alerte">{{ e }}</p> }
          <button type="button" class="gb-btn gb-btn--primaire"
                  [disabled]="texte().trim().length === 0 || envoi()" (click)="repondre()">
            @if (envoi()) { Envoi… } @else { Envoyer }
          </button>
        </div>
      }
    }
  `,
  styles: `
    .entete { padding: 1.25rem 1.25rem 0.5rem; }

    .entete__retour {
      display: inline-block;
      margin-bottom: 0.6rem;
      font-size: 0.8rem;
      font-weight: 600;
      color: var(--texte-attenue);
      text-decoration: none;
    }

    .entete__ligne { display: flex; align-items: center; justify-content: space-between; gap: 0.75rem; }
    .entete h1 { margin: 0; font-size: 1.15rem; font-weight: 700; }

    .propositions { padding: 0.75rem 1.25rem 0; display: flex; flex-direction: column; gap: 0.7rem; }

    .offre { padding: 1rem; display: flex; flex-direction: column; gap: 0.6rem; }

    /* Une offre encore vivante se distingue des mortes : sans cela, on relit
       tout le fil pour retrouver celle qui compte. */
    .offre--vive { border-color: color-mix(in srgb, var(--primaire) 45%, transparent); }

    .offre__tete { display: flex; align-items: flex-start; justify-content: space-between; gap: 0.75rem; }
    .offre__prix { margin: 0; font-size: 1.3rem; }
    .offre__detail { margin: 0.15rem 0 0; font-size: 0.76rem; color: var(--texte-attenue); }
    .offre__delai { margin: 0; font-size: 0.76rem; color: var(--alerte); }
    .offre__boutons { display: flex; gap: 0.6rem; flex-wrap: wrap; }

    .contre { display: flex; gap: 0.6rem; flex-wrap: wrap; }
    .contre__champ { flex: 1 1 10rem; min-width: 0; }

    .fil { padding: 1.5rem 1.25rem 0; display: flex; flex-direction: column; gap: 0.6rem; }

    .bulle {
      max-width: 85%;
      padding: 0.7rem 0.9rem;
      border-radius: var(--rayon-moyen);
      background: var(--surface-douce);
      align-self: flex-start;
    }

    /* Mes messages à droite, ceux d'en face à gauche : c'est la convention de
       toutes les messageries, et s'en écarter fait relire chaque bulle pour
       savoir qui parle. */
    .bulle--moi {
      align-self: flex-end;
      background: color-mix(in srgb, var(--primaire) 12%, transparent);
    }

    .bulle__texte { margin: 0; font-size: 0.88rem; line-height: 1.55; white-space: pre-line; }
    .bulle__date { margin: 0.3rem 0 0; font-size: 0.7rem; color: var(--texte-attenue); }
    /* ⚠️ --texte, et non un violet de la marque. Mesure sur la bulle : a
       11 px, --accent-titre ne tient que 4,0:1 en sombre (--primaire 3,95),
       sous le 4,5:1 exige d'un petit texte. Aucune couleur d'accent de la
       charte ne passe dans les DEUX themes ; --texte tient 15,8 et 16,0. */
    .bulle__auteur { margin: 0 0 0.25rem; font-size: 0.7rem; font-weight: 700; color: var(--texte); }

    .close {
      padding: 1.5rem 1.25rem;
      font-size: 0.83rem;
      color: var(--texte-attenue);
      line-height: 1.55;
    }

    .reponse {
      padding: 1.25rem;
      display: flex;
      flex-direction: column;
      gap: 0.6rem;
      align-items: stretch;
    }

    .zone { min-height: 5rem; resize: vertical; line-height: 1.5; }

    @media (min-width: 900px) {
      .entete, .propositions, .fil, .reponse, .close { padding-left: 0; padding-right: 0; }
      :host { display: block; max-width: 46rem; padding-top: 1.5rem; padding-bottom: 3rem; }
      .reponse { align-items: flex-end; }
      .reponse .gb-btn { align-self: flex-end; }
    }
  `,
})
export class Discussion {
  private readonly http = inject(HttpClient);
  private readonly session = inject(ServiceSession);
  private readonly tempsReel = inject(ServiceTempsReel);
  private readonly destruction = inject(DestroyRef);

  /** Lié depuis la route par `withComponentInputBinding()`. */
  readonly id = input.required<string>();

  protected readonly conversation = signal<VueConversation | null>(null);
  protected readonly propositions = signal<readonly VueProposition[]>([]);
  protected readonly chargement = signal(true);
  protected readonly erreur = signal<string | null>(null);

  protected readonly texte = signal('');
  protected readonly contre = signal<number | null>(null);
  protected readonly envoi = signal(false);
  protected readonly action = signal(false);
  protected readonly echec = signal<string | null>(null);

  protected readonly contreValide = computed(() => {
    const v = this.contre();
    return v !== null && Number.isFinite(v) && v >= 1;
  });

  constructor() {
    queueMicrotask(() => this.charger());

    // ⚠️ On COUPE a la destruction : sinon chaque discussion ouverte
    //    laisserait un abonnement de plus derriere elle.
    this.destruction.onDestroy(
      this.tempsReel.abonner<VueMessage>(
        DESTINATION_CONVERSATIONS,
        (m) => this.surMessageRecu(m),
      ),
    );
  }


  /**
   * L'arrivee d'un message, en direct.
   *
   * <h2>🎯 Il fallait recharger pour voir la reponse du conseiller</h2>
   *
   * <p>Le client posait sa question et attendait devant un ecran fige. Rien ne
   * disait si quelqu'un avait repondu — il fallait recharger pour savoir, et
   * donc recharger sans cesse.</p>
   *
   * <p>⚠️ LE MESSAGE EST AJOUTE, LE FIL N'EST PAS RELU. Redemander le fil a
   * chaque phrase ferait une requete par message — exactement ce que le temps
   * reel evite. Sur un forfait compte, la difference se voit.</p>
   *
   * <p>⚠️ On se protege du DOUBLON : le serveur pousse aux deux bouts, y
   * compris a l'expediteur. L'identifiant tranche.</p>
   */
  private surMessageRecu(message: VueMessage): void {
    const c = this.conversation();
    if (!c || message.conversationId !== c.id) {
      return;
    }
    if (c.messages.some((m) => m.id === message.id)) {
      return;
    }
    this.conversation.set({ ...c, messages: [...c.messages, message] });
  }

  protected charger(): void {
    this.chargement.set(true);
    this.erreur.set(null);

    this.http.get<VueConversation>(`/api/conversations/${this.id()}`).subscribe({
      next: (c) => {
        this.conversation.set(c);
        this.chargement.set(false);
        this.chargerLesPropositions();
      },
      error: (e: unknown) => {
        this.chargement.set(false);
        this.erreur.set(
          e instanceof HttpErrorResponse && e.status === 0
            ? 'Pas de connexion. Réessayez dans un instant.'
            : 'Cette discussion est introuvable.',
        );
      },
    });
  }

  /**
   * Les propositions, demandées à part.
   *
   * <p>⚠️ Leur échec ne masque pas le fil : une conversation sans négociation
   * est le cas le plus courant, et faire disparaître les messages pour une
   * liste vide serait absurde.</p>
   */
  private chargerLesPropositions(): void {
    this.http.get<VueProposition[]>(`/api/conversations/${this.id()}/propositions`).subscribe({
      next: (p) => this.propositions.set(p),
      error: () => this.propositions.set([]),
    });
  }

  // -------------------------------------------------------------------------

  protected repondre(): void {
    const contenu = this.texte().trim();
    if (contenu.length === 0 || this.envoi()) {
      return;
    }
    this.envoi.set(true);
    this.echec.set(null);

    this.http
      .post<VueMessage>(`/api/conversations/${this.id()}/messages`, { contenu })
      .subscribe({
        next: (m) => {
          this.envoi.set(false);
          this.texte.set('');
          // On ajoute localement plutôt que de tout recharger : le fil peut
          // être long, et le rappeler entier pour une ligne de plus coûte
          // cher sur une connexion mobile.
          this.conversation.update((c) => (c ? { ...c, messages: [...c.messages, m] } : c));
        },
        error: (e: unknown) => {
          this.envoi.set(false);
          this.echec.set(
            e instanceof HttpErrorResponse && e.status === 0
              ? 'Pas de connexion. Votre message est conservé : réessayez.'
              : 'Le message n’a pas pu être envoyé.',
          );
        },
      });
  }

  protected accepter(p: VueProposition): void {
    this.agir(this.http.post<VueProposition>(`/api/conversations/propositions/${p.id}/acceptation`, {}));
  }

  protected refuser(p: VueProposition): void {
    this.agir(this.http.post<VueProposition>(`/api/conversations/propositions/${p.id}/refus`, {}));
  }

  protected contreProposer(p: VueProposition): void {
    if (!this.contreValide()) {
      return;
    }
    this.agir(
      this.http.post<VueProposition>(
        `/api/conversations/propositions/${p.id}/contre-proposition`,
        { prixUnitaire: this.contre() },
      ),
    );
    this.contre.set(null);
  }

  /**
   * Tout geste sur une proposition recharge la LISTE ENTIÈRE.
   *
   * <p>⚠️ Et non la seule proposition renvoyée. Accepter une offre en
   * consomme d'autres, une contre-proposition en crée une nouvelle : mettre à
   * jour une seule ligne laisserait « Accepter » sur des offres que le serveur
   * vient de fermer.</p>
   */
  private agir(appel: { subscribe: (o: { next: () => void; error: (e: unknown) => void }) => void }): void {
    this.action.set(true);
    this.echec.set(null);
    appel.subscribe({
      next: () => {
        this.action.set(false);
        this.chargerLesPropositions();
      },
      error: (e: unknown) => {
        this.action.set(false);
        const detail = e instanceof HttpErrorResponse ? (e.error as { message?: string } | null)?.message : null;
        // Le serveur sait pourquoi il refuse — offre expirée, déjà consommée.
        // Son message est plus juste que celui qu'on inventerait.
        this.echec.set(detail ?? 'Ce geste n’a pas pu être enregistré.');
        this.chargerLesPropositions();
      },
    });
  }

  // -------------------------------------------------------------------------

  protected estMoi(m: VueMessage): boolean {
    return m.expediteurId === this.session.utilisateurId();
  }

  protected montant(valeur: number): string {
    return montantLisible(valeur);
  }

  protected libelleOffre(statut: string): string {
    return ETATS[statut]?.texte ?? statut;
  }

  protected classeOffre(statut: string): string {
    return ETATS[statut]?.classe ?? 'gb-etiquette--neutre';
  }

  protected libelleFil(statut: string): string {
    // ⚠️ INFORMATION tombait dans le dernier cas : une annonce se serait
    //    affichee « En attente d'un conseiller », alors que personne n'attend
    //    rien — ni le client, ni l'equipe.
    return statut === 'CLOSED'
      ? 'Close'
      : statut === 'ASSIGNED'
        ? 'Un conseiller vous suit'
        : statut === 'INFORMATION'
          ? 'Information'
          : 'En attente d’un conseiller';
  }

  protected classeFil(statut: string): string {
    return statut === 'CLOSED'
      ? 'gb-etiquette--neutre'
      : statut === 'ASSIGNED' || statut === 'INFORMATION'
        ? 'gb-etiquette--info'
        : 'gb-etiquette--alerte';
  }

  protected dateHeure(iso: string): string {
    return new Date(iso).toLocaleString('fr-FR', {
      day: 'numeric',
      month: 'short',
      hour: '2-digit',
      minute: '2-digit',
    });
  }
}
