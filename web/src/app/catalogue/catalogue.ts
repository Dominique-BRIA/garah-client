import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Component, effect, inject, input, signal, untracked } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';

import { Page, ResumeProduit, montantLisible } from '../../modeles/catalogue';

/**
 * Le catalogue.
 *
 * <p>Deux signaux distincts pour la recherche : le texte <b>saisi</b> et le
 * filtre <b>appliqué</b>. Les fondre ferait changer le message « aucun
 * résultat pour… » pendant qu'on tape, alors que la liste montre encore
 * l'ancien filtre.</p>
 *
 * <p>⚠️ Le chargement est <b>incrémental</b>, pas paginé par numéros. Sur un
 * téléphone, une barre de pagination se rate une fois sur deux — et surtout,
 * chaque page rechargée est un aller-retour de plus sur une connexion qui les
 * compte.</p>
 */
@Component({
  selector: 'gb-catalogue',
  imports: [FormsModule, RouterLink],
  templateUrl: './catalogue.html',
  styleUrl: './catalogue.scss',
})
export class Catalogue {
  private readonly http = inject(HttpClient);

  /** Liés depuis les paramètres de requête. */
  readonly recherche = input<string | undefined>(undefined);
  readonly categorieId = input<string | undefined>(undefined);

  protected readonly produits = signal<readonly ResumeProduit[]>([]);
  protected readonly total = signal(0);
  protected readonly page = signal(0);
  protected readonly derniere = signal(false);

  protected readonly chargement = signal(true);
  protected readonly chargementSuite = signal(false);
  protected readonly erreur = signal<string | null>(null);

  protected readonly saisie = signal('');
  protected readonly filtre = signal('');

  constructor() {
    // ⚠️ Un EFFET, pas un chargement unique au démarrage.
    //
    //    Depuis l'en-tête, on peut relancer une recherche alors qu'on est DÉJÀ
    //    sur le catalogue : le routeur ne recrée alors pas l'écran, il change
    //    seulement le paramètre. Un chargement écrit dans le constructeur ne
    //    serait jamais rejoué, et la page resterait sur l'ancien résultat
    //    pendant que la barre d'adresse affiche le nouveau terme.
    effect(() => {
      const terme = this.recherche() ?? '';
      this.categorieId();

      untracked(() => {
        this.saisie.set(terme);
        this.filtre.set(terme);
        this.charger(true);
      });
    });
  }

  protected charger(remiseAZero: boolean): void {
    if (remiseAZero) {
      this.page.set(0);
      this.derniere.set(false);
      this.chargement.set(true);
    } else {
      this.chargementSuite.set(true);
    }
    this.erreur.set(null);

    const parametres = new URLSearchParams({ page: String(this.page()), taille: '24' });
    if (this.categorieId()) {
      parametres.set('categorieId', this.categorieId()!);
    }
    // 🎯 La recherche part au SERVEUR. Filtrer la page reçue ne trouverait pas
    //    ce qui est en page deux, et le visiteur en conclurait que l'article
    //    n'existe pas.
    if (this.filtre()) {
      parametres.set('recherche', this.filtre());
    }

    this.http.get<Page<ResumeProduit>>(`/api/produits?${parametres}`).subscribe({
      next: (p) => {
        this.produits.update((deja) => (remiseAZero ? p.content : [...deja, ...p.content]));
        this.total.set(p.page.totalElements);
        this.derniere.set(p.page.number >= p.page.totalPages - 1);
        this.chargement.set(false);
        this.chargementSuite.set(false);
      },
      error: (e: unknown) => {
        this.chargement.set(false);
        this.chargementSuite.set(false);
        this.erreur.set(
          e instanceof HttpErrorResponse && e.status === 0
            ? 'Pas de connexion. Réessayez dans un instant.'
            : 'Le catalogue n’a pas pu être chargé.',
        );
      },
    });
  }

  protected chercher(): void {
    this.filtre.set(this.saisie().trim());
    this.charger(true);
  }

  protected effacer(): void {
    this.saisie.set('');
    this.filtre.set('');
    this.charger(true);
  }

  protected voirLaSuite(): void {
    this.page.update((n) => n + 1);
    this.charger(false);
  }

  protected montant(valeur: number | null, devise: string): string {
    return montantLisible(valeur, devise);
  }
}
