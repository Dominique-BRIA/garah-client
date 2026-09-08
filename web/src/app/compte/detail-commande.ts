import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Component, computed, inject, input, signal } from '@angular/core';
import { RouterLink } from '@angular/router';

import { montantLisible } from '../../modeles/catalogue';

interface LigneCommande {
  /*
   * L'identifiant de la LIGNE, distinct de celui de la variante. C'est lui
   * qu'un retour désigne : la ligne porte le prix figé, donc le montant
   * remboursable.
   */
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
  readonly pointRecuperationId: number | null;
  readonly montantArticles: number;
  readonly montantFrais: number;
  readonly montantRemise: number;
  readonly montantTotal: number;
  readonly devise: string;
  readonly dateCreation: string;
  readonly lignes: readonly LigneCommande[];
}

interface PointRecuperation {
  readonly id: number;
  readonly nom: string;
  readonly ville: string;
  readonly adresse: string | null;
  readonly horaires: string | null;
}

/** Ce que le serveur rend de MON retrait. Le code y est nul deux fois. */
interface MonRetrait {
  readonly numeroExpedition: string;
  readonly codeRetrait: string | null;
  readonly statut: string;
  readonly dateRetrait: string | null;
}

const LIBELLES: Record<string, { texte: string; classe: string }> = {
  EN_ATTENTE_PAIEMENT: { texte: 'À payer', classe: 'gb-etiquette--alerte' },
  PAYEE: { texte: 'Payée', classe: 'gb-etiquette--info' },
  EN_PREPARATION: { texte: 'En préparation', classe: 'gb-etiquette--info' },
  PRETE: { texte: 'Prête', classe: 'gb-etiquette--info' },
  EXPEDIEE: { texte: 'En route', classe: 'gb-etiquette--info' },
  DISPONIBLE: { texte: 'À retirer', classe: 'gb-etiquette--succes' },
  RETIREE: { texte: 'Retirée', classe: 'gb-etiquette--neutre' },
  ANNULEE: { texte: 'Annulée', classe: 'gb-etiquette--neutre' },
};

/**
 * Le détail d'une commande — et le code qui permet d'en repartir.
 *
 * <h2>🎯 Le code de retrait ne vit QUE sur cet écran</h2>
 *
 * <p>Il n'est ni dans la liste des commandes, ni dans une URL. C'est un
 * <b>secret partagé</b> : le présenter au comptoir suffit à emporter la
 * marchandise. Dans une liste, il apparaîtrait sur la capture d'écran qu'on
 * envoie à un proche pour lui montrer ses achats ; dans une URL, il finirait
 * dans les journaux du serveur, l'historique du navigateur et l'en-tête
 * {@code Referer} du premier lien cliqué.</p>
 *
 * <h2>⚠️ Un code absent ne veut pas dire « pas encore prêt »</h2>
 *
 * <p>Le serveur le tait dans <b>deux</b> situations : avant l'arrivée de la
 * marchandise, et après la remise. C'est le statut qui les distingue —
 * l'écran ne doit jamais déduire l'une de l'autre, sous peine de dire « en
 * route » à quelqu'un qui a déjà tout emporté.</p>
 *
 * <h2>Les montants viennent de la commande, jamais du catalogue</h2>
 *
 * <p>C'est ce qui rend une facture de mars encore juste en septembre. Relire
 * les prix du catalogue ferait changer un document déjà émis.</p>
 */
@Component({
  selector: 'gb-detail-commande',
  imports: [RouterLink],
  template: `
    @if (erreur(); as m) {
      <div class="gb-etat">
        <p>{{ m }}</p>
        <a routerLink="/mes-commandes" class="gb-btn gb-btn--secondaire">Mes commandes</a>
      </div>
    } @else if (chargement()) {
      <div class="gb-etat"><p>Chargement…</p></div>
    } @else if (commande(); as c) {
      <header class="entete">
        <a routerLink="/mes-commandes" class="entete__retour">Mes commandes</a>
        <div class="entete__ligne">
          <h1 class="gb-mono">{{ c.numero }}</h1>
          <span class="gb-etiquette" [class]="classe(c.statut)">{{ libelle(c.statut) }}</span>
        </div>
        <p class="entete__date">Commandé le {{ date(c.dateCreation) }}</p>
      </header>

      <!-- ================================================================ -->
      <!-- LE CODE DE RETRAIT — en tête, et rien avant                       -->
      <!-- ================================================================ -->
      <!-- C'est la seule raison d'ouvrir cet écran quand la marchandise est
           arrivée. Le mettre après la liste des articles obligerait à faire
           défiler devant l'agent du comptoir. -->
      @for (r of retraits(); track r.numeroExpedition) {
        @if (r.codeRetrait; as code) {
          <section class="gb-carte code">
            <p class="gb-libelle">Votre code de retrait</p>
            <p class="code__valeur gb-mono">{{ code }}</p>
            <p class="code__aide">
              Présentez ce code au point de récupération. Il vous sera demandé
              avant qu’on vous remette la marchandise.
            </p>
            @if (retraits().length > 1) {
              <!-- Deux marchands, deux envois : le dire, sinon on repart avec
                   la moitié de sa commande en croyant tout avoir. -->
              <p class="code__envoi">Envoi {{ r.numeroExpedition }}</p>
            }
          </section>
        } @else if (r.statut === 'CONFIRME') {
          <p class="remis">
            Marchandise remise@if (r.dateRetrait) { le {{ date(r.dateRetrait) }} }.
          </p>
        }
      }

      <!-- Où aller. Le nom, pas l'identifiant : « point 12 » n'a jamais
           conduit personne quelque part. -->
      @if (point(); as p) {
        <section class="gb-carte lieu">
          <p class="gb-libelle">Point de récupération</p>
          <p class="lieu__nom">{{ p.nom }}</p>
          <p class="lieu__ville">{{ p.ville }}</p>
          @if (p.adresse) { <p class="lieu__detail">{{ p.adresse }}</p> }
          @if (p.horaires) { <p class="lieu__detail">{{ p.horaires }}</p> }
        </section>
      }

      <section class="bloc">
        <p class="gb-libelle">Articles</p>
        <div class="lignes">
          @for (l of c.lignes; track l.id) {
            <div class="ligne">
              <div class="ligne__texte">
                <p class="ligne__nom">{{ l.designation }}</p>
                <p class="ligne__detail">
                  {{ l.quantite }} × {{ montant(l.prixUnitaire, c.devise) }}
                </p>
              </div>
              <p class="gb-montant">{{ montant(l.montantLigne, c.devise) }}</p>
            </div>
          }
        </div>
      </section>

      <section class="gb-carte total">
        <div class="total__ligne">
          <span>Articles</span>
          <span class="gb-montant">{{ montant(c.montantArticles, c.devise) }}</span>
        </div>
        <div class="total__ligne">
          <span>Frais d’acheminement</span>
          <span class="gb-montant">{{ montant(c.montantFrais, c.devise) }}</span>
        </div>
        @if (c.montantRemise > 0) {
          <div class="total__ligne">
            <span>Remise</span>
            <span class="gb-montant">− {{ montant(c.montantRemise, c.devise) }}</span>
          </div>
        }
        <div class="total__ligne total__ligne--fort">
          <span>Total payé</span>
          <span class="gb-montant">{{ montant(c.montantTotal, c.devise) }}</span>
        </div>
      </section>

      @if (c.statut === 'EN_ATTENTE_PAIEMENT') {
        <div class="actions">
          <a [routerLink]="['/paiement', c.id]" class="gb-btn gb-btn--primaire gb-btn--plein">
            Reprendre le paiement
          </a>
        </div>
      }

      <!-- ⚠️ Aucun bouton « annuler » après paiement, et ce n'est pas un
           oubli : le stock est engagé et l'acheminement peut être parti. Une
           règle métier invisible à l'écran ne protège de rien — elle produit
           des réclamations. On dit donc où s'adresser. -->
      <div class="recours">
        <p>Un problème avec cette commande ?</p>
        <div class="recours__liens">
          <!-- Le retour porte l'identifiant de LA commande : le formulaire
               s'ouvre déjà rempli du bon contexte, et personne ne recopie un
               numéro. -->
          <a [routerLink]="['/mes-retours']" [queryParams]="{ commande: c.id }"
             class="gb-btn gb-btn--secondaire">Retourner des articles</a>
          <a routerLink="/mes-reclamations" class="gb-btn gb-btn--secondaire">
            Ouvrir une réclamation
          </a>
        </div>
      </div>
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

    .entete__ligne {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 0.75rem;
    }

    .entete h1 { margin: 0; font-size: 1.15rem; font-weight: 700; }
    .entete__date { margin: 0.35rem 0 0; font-size: 0.8rem; color: var(--texte-attenue); }

    /* Le code, en très grand. Il se lit à voix haute au comptoir, souvent à
       bout de bras et parfois en plein soleil. */
    .code {
      margin: 1rem 1.25rem 0;
      padding: 1.25rem;
      text-align: center;
      border-color: color-mix(in srgb, var(--succes) 35%, transparent);
      background: color-mix(in srgb, var(--succes) 7%, var(--verre-fond));
    }

    .code__valeur {
      margin: 0.5rem 0 0;
      font-size: 2rem;
      font-weight: 700;
      /* L'espacement sépare les caractères : un code se recopie signe par
         signe, et deux lettres collées se lisent comme une seule. */
      letter-spacing: 0.22em;
      color: var(--succes);
    }

    .code__aide {
      margin: 0.75rem 0 0;
      font-size: 0.82rem;
      color: var(--texte-attenue);
      line-height: 1.5;
    }

    .code__envoi {
      margin: 0.5rem 0 0;
      font-size: 0.72rem;
      color: var(--texte-attenue);
    }

    .remis {
      margin: 1rem 1.25rem 0;
      font-size: 0.85rem;
      color: var(--texte-attenue);
    }

    .lieu { margin: 1rem 1.25rem 0; padding: 1rem; }
    .lieu__nom { margin: 0.4rem 0 0; font-size: 0.95rem; font-weight: 600; }
    .lieu__ville { margin: 0.1rem 0 0; font-size: 0.85rem; color: var(--texte-attenue); }
    .lieu__detail { margin: 0.35rem 0 0; font-size: 0.8rem; color: var(--texte-attenue); line-height: 1.5; }

    .bloc { padding: 1.5rem 1.25rem 0; }

    .lignes { margin-top: 0.6rem; display: flex; flex-direction: column; gap: 0.75rem; }

    .ligne { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; }
    .ligne__texte { min-width: 0; }
    .ligne__nom { margin: 0; font-size: 0.88rem; font-weight: 600; }
    .ligne__detail { margin: 0.15rem 0 0; font-size: 0.78rem; color: var(--texte-attenue); }

    .total {
      margin: 1.25rem 1.25rem 0;
      padding: 1rem;
      display: flex;
      flex-direction: column;
      gap: 0.5rem;
      font-size: 0.85rem;
    }

    .total__ligne { display: flex; justify-content: space-between; gap: 1rem; }

    .total__ligne--fort {
      padding-top: 0.6rem;
      border-top: 1px solid var(--verre-bordure);
      font-size: 1rem;
      font-weight: 700;
    }

    .actions { padding: 1.25rem 1.25rem 0; }

    .recours {
      padding: 1.5rem 1.25rem 2rem;
      font-size: 0.83rem;
      color: var(--texte-attenue);
      line-height: 1.6;
    }

    .recours p { margin: 0 0 0.7rem; }
    .recours__liens { display: flex; gap: 0.6rem; flex-wrap: wrap; }

    /* Sur un écran large, deux colonnes : où aller à gauche, ce qu'on a acheté
       à droite. Empiler laisserait le code de retrait seul au milieu d'un
       écran vide. */
    @media (min-width: 900px) {
      :host {
        display: grid;
        grid-template-columns: minmax(0, 1fr) minmax(0, 1.1fr);
        column-gap: 2.5rem;
        align-items: start;
        padding: 1.5rem 0 3rem;
      }

      .entete { grid-column: 1 / -1; padding: 0 0 0.5rem; }
      .code, .remis, .lieu { margin-left: 0; margin-right: 0; }
      .bloc, .actions, .recours { grid-column: 2; padding-left: 0; padding-right: 0; }
      .total { grid-column: 2; margin-left: 0; margin-right: 0; }
    }
  `,
})
export class DetailCommandeEcran {
  private readonly http = inject(HttpClient);

  /** Lié depuis la route par `withComponentInputBinding()`. */
  readonly id = input.required<string>();

  protected readonly commande = signal<DetailCommande | null>(null);
  protected readonly retraits = signal<readonly MonRetrait[]>([]);
  protected readonly points = signal<readonly PointRecuperation[]>([]);
  protected readonly chargement = signal(true);
  protected readonly erreur = signal<string | null>(null);

  /**
   * Le point de récupération, nommé.
   *
   * <p>La commande n'en porte que l'identifiant. On résout le nom côté client
   * à partir de la liste publique — <b>une</b> requête pour l'écran, jamais
   * une par ligne.</p>
   */
  protected readonly point = computed<PointRecuperation | null>(() => {
    const id = this.commande()?.pointRecuperationId;
    return id ? (this.points().find((p) => p.id === id) ?? null) : null;
  });

  constructor() {
    // `input.required` n'est pas lisible dans le constructeur : on charge au
    // premier rendu, quand la valeur est posée.
    queueMicrotask(() => this.charger());
  }

  protected charger(): void {
    this.chargement.set(true);
    this.erreur.set(null);

    this.http.get<DetailCommande>(`/api/commandes/miennes/${this.id()}`).subscribe({
      next: (c) => {
        this.commande.set(c);
        this.chargement.set(false);
        this.chargerLeRetrait();
        this.chargerLesPoints();
      },
      error: (e: unknown) => {
        this.chargement.set(false);
        this.erreur.set(message(e));
      },
    });
  }

  /**
   * Le code, demandé à part.
   *
   * <p>⚠️ Son échec ne doit <b>jamais</b> masquer la commande. Le reste de
   * l'écran — montants, articles, point de retrait — reste utile même si
   * cette requête tombe ; l'inverse ferait disparaître une facture pour un
   * code qui n'existe peut-être pas encore.</p>
   */
  private chargerLeRetrait(): void {
    this.http.get<MonRetrait[]>(`/api/expeditions/commandes/${this.id()}/mon-retrait`).subscribe({
      next: (r) => this.retraits.set(r),
      error: () => this.retraits.set([]),
    });
  }

  private chargerLesPoints(): void {
    this.http.get<PointRecuperation[]>('/api/lieux/points-recuperation').subscribe({
      next: (p) => this.points.set(p),
      // Sans les noms, l'écran affiche tout le reste : un point de retrait
      // manquant vaut mieux qu'un écran d'erreur sur une commande payée.
      error: () => this.points.set([]),
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

function message(e: unknown): string {
  if (e instanceof HttpErrorResponse) {
    if (e.status === 0) {
      return 'Pas de connexion. Réessayez dans un instant.';
    }
    if (e.status === 404) {
      // ⚠️ Le serveur répond « introuvable » AUSSI pour la commande d'un
      //    autre : un 403 confirmerait qu'elle existe. On reprend donc le mot
      //    tel quel, sans chercher à deviner laquelle des deux situations
      //    c'est — nous ne le savons pas non plus.
      return 'Cette commande est introuvable.';
    }
  }
  return 'Cette commande n’a pas pu être chargée.';
}
