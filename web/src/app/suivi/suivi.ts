import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Component, computed, effect, inject, input, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';

/** Une étape du trajet, telle que la route publique la rend. */
interface EtapeSuivi {
  readonly type: string;
  /** Le NOM du lieu, jamais son identifiant. Nul si le lieu a été supprimé. */
  readonly lieu: string | null;
  readonly ville: string | null;
  readonly observation: string | null;
  readonly dateHeure: string;
}

interface Trajet {
  readonly numeroSuivi: string;
  readonly statut: string;
  readonly etapes: readonly EtapeSuivi[];
}

const LIBELLES: Record<string, string> = {
  DEPART: 'Départ',
  ARRIVEE: 'Arrivée',
  RECEPTION: 'Réception',
  CONTROLE: 'Contrôle',
  ANOMALIE: 'Anomalie',
  REMISE: 'Remise',
};

/**
 * Le suivi public d'un colis.
 *
 * <h2>La seule page qu'on atteint sans compte</h2>
 *
 * <p>Un client reçoit un numéro par SMS, ouvre le lien, lit son trajet. Rien
 * d'autre à faire.</p>
 *
 * <p>⚠️ Un numéro de suivi circule par SMS, par WhatsApp, sur un bordereau
 * photographié : il ne prouve <b>rien</b> sur l'identité de celui qui le
 * présente. Le serveur ne rend donc que le trajet — ni contenu, ni
 * destinataire, ni agent — et cet écran n'a aucun moyen d'en afficher
 * davantage.</p>
 *
 * <p>Le numéro <b>est</b> dans l'URL, contrairement au code de retrait : un
 * numéro de suivi se partage, c'est son rôle ; un code de retrait ouvre la
 * marchandise.</p>
 */
@Component({
  selector: 'gb-suivi',
  imports: [FormsModule],
  templateUrl: './suivi.html',
  styleUrl: './suivi.scss',
})
export class Suivi {
  private readonly http = inject(HttpClient);
  private readonly router = inject(Router);

  /*
   * ⚠️ Le type ment, et c'est la ROUTE qui ment.
   *
   * Deux routes menent ici : '/suivi' seule, et '/suivi/:numero'. Sur la
   * premiere, le liage d'entrees du routeur pose `undefined` — la valeur par
   * defaut '' ne le rattrape PAS. Le `string` annonce ci-dessous est une
   * promesse faite au compilateur, que rien ne verifie a l'execution.
   *
   * Appeler `.trim()` dessus levait alors une TypeError dans l'effet de
   * construction, et Angular vidait le gabarit ENTIER : le client cliquait
   * sur « Suivre un colis » et arrivait sur une page BLANCHE. Meme defaut,
   * meme symptome et meme cause que sur l'ecran de verification d'adresse.
   */
  readonly numero = input<string | undefined>('');

  /** Le numero reellement recu, jamais `undefined`. */
  private valeurDuNumero(): string {
    return (this.numero() ?? '').trim();
  }

  protected readonly saisie = signal('');
  protected readonly trajet = signal<Trajet | null>(null);
  protected readonly chargement = signal(false);
  protected readonly erreur = signal<string | null>(null);

  /**
   * Les étapes de la plus récente à la plus ancienne.
   *
   * <p>Le serveur les range chronologiquement — le bon ordre pour un journal.
   * Ici on cherche « où est mon colis <b>maintenant</b> » : la réponse doit
   * être la première ligne, pas la dernière.</p>
   */
  protected readonly recentesDabord = computed(() => [...(this.trajet()?.etapes ?? [])].reverse());

  constructor() {
    // Arriver par un lien partagé doit lancer la recherche tout seul : sinon
    // le client voit un champ vide alors qu'il a cliqué sur un lien qui
    // contenait déjà sa réponse.
    effect(() => {
      const n = this.valeurDuNumero();
      if (n) {
        this.saisie.set(n);
        this.chercher(n);
      }
    });
  }

  protected soumettre(): void {
    const n = this.saisie().trim();
    if (n) {
      this.router.navigate(['/suivi', n]);
    }
  }

  private chercher(numeroSuivi: string): void {
    this.chargement.set(true);
    this.erreur.set(null);

    this.http.get<Trajet>(`/api/expeditions/suivi/${encodeURIComponent(numeroSuivi)}`).subscribe({
      next: (t) => {
        this.chargement.set(false);
        this.trajet.set(t);
      },
      error: (e: unknown) => {
        this.chargement.set(false);
        this.trajet.set(null);
        this.erreur.set(message(e));
      },
    });
  }

  protected libelle(type: string): string {
    return LIBELLES[type] ?? type;
  }

  protected ou(e: EtapeSuivi): string {
    if (!e.lieu && !e.ville) {
      return 'Lieu non précisé';
    }
    return e.ville ? `${e.lieu ?? ''} · ${e.ville}`.trim() : (e.lieu ?? '');
  }

  protected quand(iso: string): string {
    return new Date(iso).toLocaleString('fr-FR', {
      day: '2-digit',
      month: 'long',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  }

  protected estAnomalie(type: string): boolean {
    return type === 'ANOMALIE';
  }
}

/**
 * Un 404 dit « ce numéro n'existe pas », pas « erreur technique ».
 *
 * <p>C'est le cas le plus fréquent ici : un chiffre mal recopié depuis un SMS.
 * Le message doit inviter à vérifier la saisie, pas laisser croire à une
 * panne.</p>
 */
function message(e: unknown): string {
  if (e instanceof HttpErrorResponse) {
    if (e.status === 0) {
      return 'Pas de connexion. Réessayez dans un instant.';
    }
    if (e.status === 404) {
      return 'Aucun colis ne porte ce numéro. Vérifiez les caractères saisis.';
    }
  }
  return 'Le suivi n’a pas pu être affiché.';
}
