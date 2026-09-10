import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Component, computed, inject, input, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';

import { Page, montantLisible } from '../../modeles/catalogue';
import { RetourCompte } from './retour-compte';

interface LigneCommande {
  readonly id: number;
  readonly varianteId: number;
  readonly designation: string;
  readonly quantite: number;
  readonly prixUnitaire: number;
  readonly montantLigne: number;
}

interface DetailCommande {
  readonly id: number;
  readonly numero: string;
  readonly statut: string;
  readonly devise: string;
  readonly lignes: readonly LigneCommande[];
}

interface VueRetour {
  readonly id: number;
  readonly numero: string;
  readonly commandeId: number;
  readonly motif: string;
  readonly statut: string;
  readonly dateCreation: string;
  readonly dateReception: string | null;
}

/** L'état déclaré à l'envoi. Il sera VÉRIFIÉ à la réception, pas cru sur parole. */
const ETATS: readonly { code: string; libelle: string }[] = [
  { code: 'NEUF', libelle: 'Comme neuf, jamais utilisé' },
  { code: 'ABIME', libelle: 'Abîmé' },
  { code: 'INUTILISABLE', libelle: 'Inutilisable' },
];

const LIBELLES: Record<string, { texte: string; classe: string }> = {
  DEMANDE: { texte: 'Demandé', classe: 'gb-etiquette--alerte' },
  ACCEPTE: { texte: 'Accepté', classe: 'gb-etiquette--info' },
  REFUSE: { texte: 'Refusé', classe: 'gb-etiquette--neutre' },
  RECEPTIONNE: { texte: 'Colis reçu', classe: 'gb-etiquette--info' },
  VALIDE: { texte: 'Remboursement validé', classe: 'gb-etiquette--succes' },
  CLOTURE: { texte: 'Clos', classe: 'gb-etiquette--neutre' },
};

/**
 * Mes retours — la liste, et la demande.
 *
 * <h2>🎯 On désigne des LIGNES DE COMMANDE, pas des produits</h2>
 *
 * <p>C'est la ligne qui porte le <b>prix figé</b>, donc le montant
 * remboursable. Passer par le produit obligerait à retrouver « à quel prix
 * l'avait-il payé ? » — exactement la question que la photographie des prix a
 * supprimée, et à laquelle un catalogue qui a bougé depuis répondrait faux.</p>
 *
 * <h2>⚠️ L'état déclaré est une DÉCLARATION, pas un constat</h2>
 *
 * <p>Il sera vérifié à l'ouverture du colis. L'écran ne doit donc rien
 * promettre : ni montant, ni délai. Annoncer un remboursement calculé sur un
 * « comme neuf » déclaré ferait attendre une somme que personne n'a
 * validée.</p>
 *
 * <h2>La quantité est bornée à ce qui a été acheté</h2>
 *
 * <p>Un déclencheur en base refuse d'en retourner plus, retours précédents
 * compris. Mais une règle qui ne vit qu'en base produit une erreur au dernier
 * moment : l'écran borne aussi, pour que le refus n'arrive jamais.</p>
 */
@Component({
  selector: 'gb-retours',
  imports: [FormsModule, RouterLink, RetourCompte],
  template: `
    <gb-retour-compte />

    <header class="entete">
      <h1>Mes retours</h1>
      <p class="entete__aide">Un conseiller examine chaque demande.</p>
    </header>


    @if (commande(); as c) {
      <section class="gb-carte formulaire">
        <p class="gb-libelle">Retourner des articles</p>
        <p class="formulaire__commande gb-mono">{{ c.numero }}</p>

        <div class="lignes">
          @for (l of c.lignes; track l.id) {
            <div class="ligne" [class.ligne--choisie]="quantiteDe(l.id) > 0">
              <label class="ligne__titre">
                <input type="checkbox" [checked]="quantiteDe(l.id) > 0"
                       (change)="basculer(l)" [attr.aria-label]="'Retourner ' + l.designation" />
                <span>
                  <span class="ligne__nom">{{ l.designation }}</span>
                  <span class="ligne__achat">
                    {{ l.quantite }} acheté(s) · {{ montant(l.prixUnitaire, c.devise) }} l’unité
                  </span>
                </span>
              </label>

              @if (quantiteDe(l.id) > 0) {
                <div class="ligne__reglages">
                  <div class="compteur">
                    <button type="button" (click)="changer(l, -1)" aria-label="Retirer une unité">−</button>
                    <span>{{ quantiteDe(l.id) }}</span>
                    <button type="button" (click)="changer(l, 1)" aria-label="Ajouter une unité">+</button>
                  </div>

                  <select class="gb-champ etat" [ngModel]="etatDe(l.id)"
                          (ngModelChange)="poserEtat(l.id, $event)"
                          [name]="'etat-' + l.id" aria-label="État de l’article">
                    @for (e of ETATS; track e.code) {
                      <option [value]="e.code">{{ e.libelle }}</option>
                    }
                  </select>
                </div>
              }
            </div>
          }
        </div>

        <label class="champ">
          <span class="gb-libelle">Pourquoi ce retour</span>
          <textarea class="gb-champ zone" name="motif" rows="4" maxlength="500"
                    placeholder="Ce qui ne va pas avec ces articles."
                    [ngModel]="motif()" (ngModelChange)="motif.set($event)"></textarea>
        </label>

        @if (manque(); as m) {
          <p class="manque">{{ m }}</p>
        }
        @if (echec(); as e) {
          <p class="gb-alerte">{{ e }}</p>
        }

        <!-- Ce que la demande fait, et surtout ce qu'elle ne fait pas. -->
        <p class="prevenu">
          L’état que vous indiquez sera vérifié à l’ouverture du colis. Le
          montant remboursé est arrêté à ce moment-là, pas maintenant.
        </p>

        <div class="boutons">
          <a routerLink="/mes-retours" class="gb-btn gb-btn--secondaire">Annuler</a>
          <button type="button" class="gb-btn gb-btn--primaire"
                  [disabled]="manque() !== null || envoi()" (click)="envoyer()">
            @if (envoi()) { Envoi… } @else { Demander le retour }
          </button>
        </div>
      </section>
    } @else if (commandeId()) {
      <div class="gb-etat"><p>Chargement de la commande…</p></div>
    }

    @if (erreur(); as m) {
      <div class="gb-etat">
        <p>{{ m }}</p>
        <button type="button" class="gb-btn gb-btn--secondaire" (click)="charger()">Réessayer</button>
      </div>
    } @else if (chargement()) {
      <div class="gb-etat"><p>Chargement…</p></div>
    } @else if (retours().length === 0) {
      <p class="gb-etat gb-attenue">Vous n’avez demandé aucun retour.</p>
    } @else {
      <div class="liste">
        @for (r of retours(); track r.id) {
          <article class="gb-carte dossier">
            <div class="dossier__tete">
              <p class="dossier__numero gb-mono">{{ r.numero }}</p>
              <span class="gb-etiquette" [class]="classe(r.statut)">{{ libelle(r.statut) }}</span>
            </div>
            <p class="dossier__texte">{{ r.motif }}</p>
            <p class="dossier__date">
              Demandé le {{ date(r.dateCreation) }}@if (r.dateReception) { · colis reçu le {{ date(r.dateReception) }} }
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

    .formulaire {
      margin: 1.25rem;
      padding: 1.25rem;
      display: flex;
      flex-direction: column;
      gap: 0.9rem;
    }

    .formulaire__commande { margin: 0; font-size: 0.85rem; font-weight: 700; }

    .lignes { display: flex; flex-direction: column; gap: 0.6rem; }

    .ligne {
      padding: 0.75rem;
      border: 1px solid var(--verre-bordure);
      border-radius: var(--rayon-petit);
    }

    .ligne--choisie { border-color: color-mix(in srgb, var(--primaire) 45%, transparent); }

    .ligne__titre {
      display: flex;
      align-items: flex-start;
      gap: 0.7rem;
      cursor: pointer;

      input { margin-top: 0.15rem; width: 18px; height: 18px; flex-shrink: 0; accent-color: var(--primaire); }
      span { display: block; }
    }

    .ligne__nom { display: block; font-size: 0.88rem; font-weight: 600; }
    .ligne__achat { display: block; margin-top: 0.15rem; font-size: 0.76rem; color: var(--texte-attenue); }

    .ligne__reglages {
      margin-top: 0.75rem;
      display: flex;
      align-items: center;
      gap: 0.75rem;
      flex-wrap: wrap;
    }

    .compteur {
      display: inline-flex;
      align-items: center;
      border: 1px solid var(--champ-bordure);
      border-radius: var(--rayon-petit);
      overflow: hidden;

      button {
        width: 38px;
        height: 38px;
        border: none;
        background: var(--surface-douce);
        color: var(--texte);
        font-size: 1.05rem;
        font-weight: 700;
        cursor: pointer;
      }

      span { min-width: 2.4rem; text-align: center; font-variant-numeric: tabular-nums; font-weight: 700; }
    }

    .etat { flex: 1 1 12rem; min-height: 38px; font-size: 0.85rem; }

    .champ { display: block; }
    .zone { min-height: 6rem; resize: vertical; line-height: 1.5; }

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

    .dossier__tete { display: flex; align-items: center; justify-content: space-between; gap: 0.75rem; }
    .dossier__numero { margin: 0; font-size: 0.85rem; font-weight: 700; }
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
      .compteur button:hover { background: var(--surface-douce-survol); }
    }

    @media (min-width: 900px) {
      .entete, .liste { padding-left: 0; padding-right: 0; }
      .formulaire { margin-left: 0; margin-right: 0; max-width: 44rem; }
      .liste { max-width: 44rem; }
    }
  `,
})
export class Retours {
  private readonly http = inject(HttpClient);
  private readonly routeur = inject(Router);

  /** Lié depuis `?commande=`. Absent : on n'affiche que la liste. */
  readonly commande_ = input<string | undefined>(undefined, { alias: 'commande' });

  protected readonly ETATS = ETATS;

  protected readonly retours = signal<readonly VueRetour[]>([]);
  protected readonly commande = signal<DetailCommande | null>(null);
  protected readonly chargement = signal(true);
  protected readonly erreur = signal<string | null>(null);

  /** Ligne de commande → quantité choisie. Absente = non retournée. */
  protected readonly choix = signal<ReadonlyMap<number, number>>(new Map());
  protected readonly etats = signal<ReadonlyMap<number, string>>(new Map());
  protected readonly motif = signal('');
  protected readonly envoi = signal(false);
  protected readonly echec = signal<string | null>(null);

  protected readonly commandeId = computed(() => this.commande_() ?? null);

  protected readonly manque = computed<string | null>(() => {
    if (this.choix().size === 0) {
      return 'Choisissez au moins un article à retourner.';
    }
    if (this.motif().trim().length < 5) {
      return 'Dites en une phrase pourquoi vous renvoyez ces articles.';
    }
    return null;
  });

  constructor() {
    queueMicrotask(() => this.charger());
  }

  protected charger(): void {
    this.chargement.set(true);
    this.erreur.set(null);

    this.http.get<Page<VueRetour>>('/api/sav/retours/miens?taille=50').subscribe({
      next: (p) => {
        this.retours.set(p.content);
        this.chargement.set(false);
      },
      error: (e: unknown) => {
        this.chargement.set(false);
        this.erreur.set(
          e instanceof HttpErrorResponse && e.status === 0
            ? 'Pas de connexion. Réessayez dans un instant.'
            : 'Vos retours n’ont pas pu être chargés.',
        );
      },
    });

    const id = this.commandeId();
    if (id) {
      this.http.get<DetailCommande>(`/api/commandes/miennes/${id}`).subscribe({
        next: (c) => this.commande.set(c),
        // Sans la commande, le formulaire ne s'affiche pas — mais la liste
        // des retours déjà demandés, elle, reste utile.
        error: () => this.commande.set(null),
      });
    }
  }

  // -------------------------------------------------------------------------

  protected quantiteDe(ligneId: number): number {
    return this.choix().get(ligneId) ?? 0;
  }

  protected etatDe(ligneId: number): string {
    return this.etats().get(ligneId) ?? 'NEUF';
  }

  protected basculer(l: LigneCommande): void {
    const copie = new Map(this.choix());
    if (copie.has(l.id)) {
      copie.delete(l.id);
    } else {
      copie.set(l.id, 1);
    }
    this.choix.set(copie);
  }

  protected changer(l: LigneCommande, delta: number): void {
    const copie = new Map(this.choix());
    // ⚠️ Borné à la quantité ACHETÉE. Un déclencheur en base refuse d'en
    //    retourner plus, mais une règle qui ne vit qu'en base produit une
    //    erreur au dernier moment, après que tout a été saisi.
    const suivante = Math.min(Math.max((copie.get(l.id) ?? 0) + delta, 1), l.quantite);
    copie.set(l.id, suivante);
    this.choix.set(copie);
  }

  protected poserEtat(ligneId: number, etat: string): void {
    const copie = new Map(this.etats());
    copie.set(ligneId, etat);
    this.etats.set(copie);
  }

  protected envoyer(): void {
    const c = this.commande();
    if (!c || this.manque() !== null || this.envoi()) {
      return;
    }
    this.envoi.set(true);
    this.echec.set(null);

    const lignes = [...this.choix().entries()].map(([ligneCommandeId, quantite]) => ({
      ligneCommandeId,
      quantite,
      etatArticle: this.etatDe(ligneCommandeId),
    }));

    this.http
      .post<VueRetour>('/api/sav/retours', { commandeId: c.id, motif: this.motif().trim(), lignes })
      .subscribe({
        next: (r) => {
          this.envoi.set(false);
          this.retours.update((l) => [r, ...l]);
          this.commande.set(null);
          this.choix.set(new Map());
          this.motif.set('');
          // On quitte le paramètre `?commande=` : rester dessus ferait
          // réapparaître le formulaire au prochain rechargement, sur une
          // demande déjà envoyée.
          this.routeur.navigate(['/mes-retours']);
        },
        error: (e: unknown) => {
          this.envoi.set(false);
          this.echec.set(messageRetour(e));
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

  protected montant(valeur: number, devise: string): string {
    return montantLisible(valeur, devise);
  }

  protected date(iso: string): string {
    return new Date(iso).toLocaleDateString('fr-FR', {
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    });
  }
}

function messageRetour(e: unknown): string {
  if (e instanceof HttpErrorResponse) {
    if (e.status === 0) {
      return 'Pas de connexion. Votre saisie est conservée : réessayez.';
    }
    // Le serveur refuse aussi de retourner plus qu'on n'a acheté, retours
    // précédents compris. Son message est plus précis que le nôtre : on le
    // reprend tel quel plutôt que d'en inventer un.
    const detail = (e.error as { message?: string } | null)?.message;
    if (detail) {
      return detail;
    }
  }
  return 'La demande de retour n’a pas pu être envoyée.';
}
