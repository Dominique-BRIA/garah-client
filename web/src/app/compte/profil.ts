import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';

import { ServiceNotifications } from '../../services/notifications';
import { ServiceSession } from '../../services/session';
import { MenuCompte } from './menu-compte';

interface MonProfil {
  readonly id: number;
  readonly nom: string;
  readonly prenom: string | null;
  readonly email: string;
  readonly telephone: string | null;
  readonly langue: string;
  readonly emailVerifie: boolean;
}

/**
 * Mon compte.
 *
 * <h2>Ce qui se modifie, et ce qui ne se modifie pas</h2>
 *
 * <p>Nom, prénom, téléphone, langue : oui. <b>L'adresse e-mail : non.</b> Elle
 * identifie le compte, sert à s'y connecter, et a été vérifiée. En changer est
 * un parcours à part entière — vérifier qu'elle est libre, repasser
 * {@code emailVerifie} à faux, réémettre un lien — et non un champ de
 * formulaire. Le serveur ne l'accepte d'ailleurs pas.</p>
 *
 * <p>On le <b>dit</b> plutôt que d'afficher un champ grisé : un champ qu'on ne
 * peut pas remplir donne envie d'essayer.</p>
 */
@Component({
  selector: 'gb-profil',
  imports: [FormsModule, RouterLink, MenuCompte],
  templateUrl: './profil.html',
  styleUrl: './profil.scss',
})
export class Profil {
  protected readonly notifications = inject(ServiceNotifications);

  /** Ce qui a empêché l'activation, dit à l'écran. */
  protected readonly echecAlertes = signal<string | null>(null);

  protected async activerLesAlertes(): Promise<void> {
    this.echecAlertes.set(await this.notifications.activer());
  }

  private readonly http = inject(HttpClient);
  protected readonly session = inject(ServiceSession);

  protected readonly profil = signal<MonProfil | null>(null);
  protected readonly chargement = signal(true);

  // --- Coordonnées ---
  protected readonly edition = signal(false);
  protected readonly nom = signal('');
  protected readonly prenom = signal('');
  protected readonly telephone = signal('');
  protected readonly langue = signal('fr');
  protected readonly envoi = signal(false);
  protected readonly erreur = signal<string | null>(null);
  protected readonly enregistre = signal(false);

  // --- Mot de passe ---
  protected readonly formMotDePasse = signal(false);
  protected readonly actuel = signal('');
  protected readonly nouveau = signal('');
  protected readonly confirmation = signal('');
  protected readonly envoiMotDePasse = signal(false);
  protected readonly erreurMotDePasse = signal<string | null>(null);
  protected readonly motDePasseChange = signal(false);

  constructor() {
    this.charger();
  }

  protected charger(): void {
    this.chargement.set(true);

    this.http.get<MonProfil>('/api/profil').subscribe({
      next: (p) => {
        this.profil.set(p);
        this.chargement.set(false);
      },
      error: () => this.chargement.set(false),
    });
  }

  // -------------------------------------------------------------------------
  // Les coordonnées
  // -------------------------------------------------------------------------

  protected ouvrirEdition(): void {
    const p = this.profil();
    if (!p) {
      return;
    }
    this.nom.set(p.nom);
    this.prenom.set(p.prenom ?? '');
    this.telephone.set(p.telephone ?? '');
    this.langue.set(p.langue || 'fr');
    this.erreur.set(null);
    this.enregistre.set(false);
    this.edition.set(true);
  }

  protected enregistrer(): void {
    if (this.envoi() || !this.nom().trim()) {
      return;
    }
    this.envoi.set(true);
    this.erreur.set(null);

    // ⚠️ `PATCH`, pas `PUT` : le serveur ne modifie que les champs présents.
    //    Envoyer la fiche entière écraserait ce que cet écran n'affiche pas.
    this.http
      .patch<MonProfil>('/api/profil', {
        nom: this.nom().trim(),
        prenom: this.prenom().trim() || null,
        telephone: this.telephone().trim() || null,
        langue: this.langue(),
      })
      .subscribe({
        next: (p) => {
          this.envoi.set(false);
          this.profil.set(p);
          this.edition.set(false);
          this.enregistre.set(true);
        },
        error: (e: unknown) => {
          this.envoi.set(false);
          this.erreur.set(message(e, 'Vos coordonnées n’ont pas pu être enregistrées.'));
        },
      });
  }

  // -------------------------------------------------------------------------
  // Le mot de passe
  // -------------------------------------------------------------------------

  protected ouvrirMotDePasse(): void {
    this.actuel.set('');
    this.nouveau.set('');
    this.confirmation.set('');
    this.erreurMotDePasse.set(null);
    this.motDePasseChange.set(false);
    this.formMotDePasse.set(true);
  }

  protected motDePasseValide(): boolean {
    return (
      this.actuel().length > 0 &&
      this.nouveau().length >= 8 &&
      this.nouveau() === this.confirmation()
    );
  }

  /**
   * ⚠️ La confirmation est vérifiée <b>ici seulement</b> : le serveur ne la
   *    connaît pas, elle n'est qu'un garde-fou contre la faute de frappe. Se
   *    tromper en changeant son mot de passe enferme dehors.
   */
  protected changerMotDePasse(): void {
    if (!this.motDePasseValide() || this.envoiMotDePasse()) {
      return;
    }
    this.envoiMotDePasse.set(true);
    this.erreurMotDePasse.set(null);

    this.http
      .post('/api/profil/mot-de-passe', { actuel: this.actuel(), nouveau: this.nouveau() })
      .subscribe({
        next: () => {
          this.envoiMotDePasse.set(false);
          this.formMotDePasse.set(false);
          this.motDePasseChange.set(true);
        },
        error: (e: unknown) => {
          this.envoiMotDePasse.set(false);
          this.erreurMotDePasse.set(
            message(e, 'Le mot de passe n’a pas pu être changé.'),
          );
        },
      });
  }

  protected seDeconnecter(): void {
    this.session.deconnecter().subscribe(() => {
      window.location.href = '/';
    });
  }
}

function message(e: unknown, repli: string): string {
  if (e instanceof HttpErrorResponse) {
    if (e.status === 0) {
      return 'Pas de connexion. Réessayez dans un instant.';
    }
    const corps = e.error as { message?: string } | null;
    if (corps?.message) {
      return corps.message;
    }
  }
  return repli;
}
