import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';

import { Categorie, ResumeProduit, montantLisible } from '../../modeles/catalogue';

/**
 * L'accueil de la vitrine.
 *
 * <p>Il répond à « qu'est-ce qui se vend ici ? » avant toute recherche — la
 * question que se pose quelqu'un qui arrive par un lien partagé et ne connaît
 * pas GARAH.</p>
 *
 * <p>⚠️ Les deux appels sont <b>indépendants</b> : un catalogue neuf n'a
 * aucune tendance, et un échec sur l'un ne doit pas vider l'autre. Les lier
 * ferait disparaître l'accueil entier pour une carte manquante.</p>
 */
@Component({
  selector: 'gb-accueil',
  imports: [FormsModule, RouterLink],
  templateUrl: './accueil.html',
  styleUrl: './accueil.scss',
})
export class Accueil {
  private readonly http = inject(HttpClient);
  private readonly router = inject(Router);

  protected readonly tendances = signal<readonly ResumeProduit[]>([]);
  protected readonly categories = signal<readonly Categorie[]>([]);

  protected readonly chargement = signal(true);
  protected readonly erreur = signal<string | null>(null);

  protected readonly recherche = signal('');

  constructor() {
    this.charger();
  }

  protected charger(): void {
    this.chargement.set(true);
    this.erreur.set(null);

    this.http.get<ResumeProduit[]>('/api/produits/tendance?limite=6').subscribe({
      next: (p) => {
        this.tendances.set(p);
        this.chargement.set(false);
      },
      error: (e: unknown) => {
        this.chargement.set(false);
        this.erreur.set(message(e));
      },
    });

    // Sans bloquer : l'accueil reste lisible sans ses catégories.
    this.http.get<Categorie[]>('/api/categories').subscribe({
      next: (c) => this.categories.set(c.filter((x) => x.parentId === null).slice(0, 6)),
      error: () => this.categories.set([]),
    });
  }

  protected chercher(): void {
    const q = this.recherche().trim();
    this.router.navigate(['/catalogue'], q ? { queryParams: { recherche: q } } : {});
  }

  protected montant(valeur: number | null, devise: string): string {
    return montantLisible(valeur, devise);
  }
}

function message(e: unknown): string {
  if (e instanceof HttpErrorResponse && e.status === 0) {
    // ⚠️ Le cas le plus fréquent ici, et il n'est PAS une panne du serveur :
    //    une connexion coupée en pleine rue. Le dire comme tel évite de faire
    //    croire que la boutique est fermée.
    return 'Pas de connexion. Réessayez dans un instant.';
  }
  return 'La boutique n’a pas pu être chargée.';
}
