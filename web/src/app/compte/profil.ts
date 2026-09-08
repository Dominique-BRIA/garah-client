import { HttpClient } from '@angular/common/http';
import { Component, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';

interface MonProfil {
  readonly nom: string;
  readonly email: string;
  readonly telephone: string | null;
  readonly emailVerifie: boolean;
}

/**
 * Mon compte.
 *
 * <p>Première passe : la lecture. La modification des coordonnées et le
 * changement de mot de passe suivront — les routes existent
 * ({@code PUT /api/profil}, {@code POST /api/profil/mot-de-passe}).</p>
 */
@Component({
  selector: 'gb-profil',
  imports: [RouterLink],
  template: `
    <header class="entete"><h1>Mon compte</h1></header>

    @if (chargement()) {
      <div class="gb-etat"><p>Chargement…</p></div>
    } @else if (profil(); as p) {
      <dl class="infos">
        <div>
          <dt>Nom</dt>
          <dd>{{ p.nom }}</dd>
        </div>
        <div>
          <dt>Adresse e-mail</dt>
          <dd>
            {{ p.email }}
            @if (!p.emailVerifie) {
              <!-- ⚠️ Pas décoratif : un compte non vérifié ne reçoit AUCUN
                   courriel — ni confirmation de commande, ni lien de suivi. -->
              <span class="non-verifie">non confirmée</span>
            }
          </dd>
        </div>
        <div>
          <dt>Téléphone</dt>
          <dd>{{ p.telephone ?? '—' }}</dd>
        </div>
      </dl>

      @if (!p.emailVerifie) {
        <p class="avertissement">
          Tant que votre adresse n’est pas confirmée, vous ne recevrez ni
          confirmation de commande ni lien de suivi. Le lien vous a été envoyé
          à l’inscription.
        </p>
      }
    } @else {
      <div class="gb-etat"><p>Votre profil n’a pas pu être chargé.</p></div>
    }

    <div class="liens">
      <a routerLink="/mes-commandes" class="gb-btn gb-btn--secondaire gb-btn--plein">
        Mes commandes
      </a>
    </div>
  `,
  styles: `
    .entete { padding: 1.5rem 1.25rem 1rem; }
    .entete h1 { margin: 0; font-size: 1.3rem; font-weight: 700; }

    .infos {
      margin: 0;
      padding: 0 1.25rem;
      display: flex;
      flex-direction: column;
      gap: 1rem;

      dt {
        font-size: 0.72rem;
        font-weight: 700;
        letter-spacing: 0.06em;
        text-transform: uppercase;
        color: var(--texte-attenue);
        margin-bottom: 0.25rem;
      }

      dd { margin: 0; font-size: 0.9rem; overflow-wrap: anywhere; }
    }

    .non-verifie {
      margin-left: 0.4rem;
      font-size: 0.72rem;
      font-weight: 600;
      color: var(--alerte);
    }

    .avertissement {
      margin: 1.25rem 1.25rem 0;
      padding: 0.85rem 1rem;
      border-radius: var(--rayon-petit);
      background: color-mix(in srgb, var(--alerte) 8%, transparent);
      border: 1px solid color-mix(in srgb, var(--alerte) 25%, transparent);
      font-size: 0.8rem;
      line-height: 1.55;
    }

    .liens { padding: 1.5rem 1.25rem; }
  `,
})
export class Profil {
  private readonly http = inject(HttpClient);

  protected readonly profil = signal<MonProfil | null>(null);
  protected readonly chargement = signal(true);

  constructor() {
    this.http.get<MonProfil>('/api/profil').subscribe({
      next: (p) => {
        this.profil.set(p);
        this.chargement.set(false);
      },
      error: () => this.chargement.set(false),
    });
  }
}
