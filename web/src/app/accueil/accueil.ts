import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';

import { Categorie, Page, ResumeProduit, montantLisible } from '../../modeles/catalogue';
import { BasculeTheme } from '../bascule-theme';
import { Marque } from '../marque';
import { ServiceTheme } from '../../services/theme';

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
  imports: [FormsModule, RouterLink, Marque, BasculeTheme],
  templateUrl: './accueil.html',
  styleUrl: './accueil.scss',
})
export class Accueil {
  private readonly http = inject(HttpClient);
  private readonly router = inject(Router);
  protected readonly theme = inject(ServiceTheme);

  protected readonly tendances = signal<readonly ResumeProduit[]>([]);

  /**
   * Le reste du catalogue, sous les tendances.
   *
   * <p>🎯 Sans lui, un catalogue neuf n'a <b>rien</b> à montrer : les
   * tendances se calculent sur des ventes, et il n'y en a pas encore. Un
   * visiteur arrivait donc sur un accueil vide alors que la boutique a des
   * produits — le pire premier contact possible.</p>
   *
   * <p>⚠️ Les produits déjà en tendance en sont <b>retirés</b> : les voir deux
   * fois sur le même écran fait douter de ce qu'on regarde.</p>
   */
  protected readonly autres = signal<readonly ResumeProduit[]>([]);
  protected readonly chargementAutres = signal(true);
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
        // Le catalogue est demandé APRÈS les tendances : il a besoin de savoir
        // lesquelles retirer, et les lancer en parallèle obligerait à
        // dédoublonner deux fois.
        this.chargerLeReste();
      },
      error: (e: unknown) => {
        this.chargement.set(false);
        this.erreur.set(message(e));
        // ⚠️ On charge le catalogue MÊME si les tendances échouent : sinon un
        //    agrégat manquant viderait tout l'accueil, alors que la boutique
        //    a des produits à montrer.
        this.chargerLeReste();
      },
    });

    // Sans bloquer : l'accueil reste lisible sans ses catégories.
    this.http.get<Categorie[]>('/api/categories').subscribe({
      next: (c) => this.categories.set(c.filter((x) => x.parentId === null).slice(0, 6)),
      error: () => this.categories.set([]),
    });
  }

  /** Le catalogue, moins ce qui est déjà en tendance. */
  private chargerLeReste(): void {
    this.chargementAutres.set(true);

    // Douze : de quoi remplir trois rangées sur un écran large sans faire du
    // catalogue entier une page d'accueil. « Tout voir » mène au reste.
    this.http.get<Page<ResumeProduit>>('/api/produits?taille=12').subscribe({
      next: (page) => {
        const dejaVus = new Set(this.tendances().map((p) => p.id));
        this.autres.set(page.content.filter((p) => !dejaVus.has(p.id)));
        this.chargementAutres.set(false);
      },
      error: () => {
        this.autres.set([]);
        this.chargementAutres.set(false);
      },
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
