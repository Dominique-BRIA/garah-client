import { HttpClient } from '@angular/common/http';
import { Injectable, computed, effect, inject, signal } from '@angular/core';

import { ServiceSession } from './session';

/**
 * Ma liste d'envies.
 *
 * <h2>🎯 Un seul appel, gardé en mémoire</h2>
 *
 * <p>Le cœur d'un article doit se dessiner rempli ou vide <b>tout de suite</b>,
 * sur chaque vignette d'une grille de vingt-quatre. Demander au serveur « ce
 * produit est-il en favori ? » ligne par ligne ferait vingt-quatre requêtes
 * pour une page — exactement ce que la règle du projet interdit.</p>
 *
 * <p>La liste complète tient dans un {@code Set} d'identifiants : quelques
 * centaines d'entiers au pire, chargés une fois à la connexion.</p>
 *
 * <h2>⚠️ Le cœur bascule AVANT la réponse du serveur</h2>
 *
 * <p>Et il revient en arrière si l'appel échoue. C'est délibéré : sur une
 * connexion lente, attendre l'aller-retour donne un bouton qui ne réagit pas,
 * et on clique trois fois. Le retour en arrière est visible, donc honnête —
 * l'inverse, un cœur qui reste rempli sur un enregistrement raté, ferait
 * croire à une liste qu'on n'a pas.</p>
 *
 * <h2>Sans compte, il n'y a pas de favoris</h2>
 *
 * <p>Contrairement au panier, qui vit dans le navigateur et fusionne à la
 * connexion. La différence n'est pas un oubli : un panier local sert à
 * <b>acheter tout de suite</b>, une liste d'envies sert à <b>revenir</b> —
 * or on revient rarement depuis le même navigateur, et une liste perdue au
 * changement d'appareil serait pire que pas de liste du tout.</p>
 */
@Injectable({ providedIn: 'root' })
export class ServiceFavoris {
  private readonly http = inject(HttpClient);
  private readonly session = inject(ServiceSession);

  private readonly ids = signal<ReadonlySet<number>>(new Set());

  /** Dans l'ordre d'ajout le plus récent — celui que le serveur rend. */
  private readonly ordre = signal<readonly number[]>([]);

  readonly liste = this.ordre.asReadonly();
  readonly nombre = computed(() => this.ids().size);

  constructor() {
    // La liste suit la session : chargée à la connexion, vidée à la
    // déconnexion. La garder après coup montrerait les envies du compte
    // précédent sur un téléphone partagé.
    effect(() => {
      if (this.session.connecte()) {
        this.charger();
      } else {
        this.ids.set(new Set());
        this.ordre.set([]);
      }
    });
  }

  estFavori(produitId: number): boolean {
    return this.ids().has(produitId);
  }

  /**
   * Ajoute ou retire, selon l'état courant.
   *
   * <p>Rend {@code false} si l'appel n'a pas pu être tenté — sans compte,
   * typiquement. L'écran s'en sert pour proposer la connexion plutôt que de
   * laisser un bouton sans effet.</p>
   */
  basculer(produitId: number): boolean {
    if (!this.session.connecte()) {
      return false;
    }

    const etait = this.estFavori(produitId);
    this.poser(produitId, !etait);

    const appel = etait
      ? this.http.delete<void>(`/api/favoris/${produitId}`)
      : this.http.put<void>(`/api/favoris/${produitId}`, {});

    appel.subscribe({
      // On remet comme c'était : un cœur rempli sur un enregistrement raté
      // ferait croire à une liste qu'on n'a pas.
      error: () => this.poser(produitId, etait),
    });

    return true;
  }

  charger(): void {
    this.http.get<number[]>('/api/favoris/miens').subscribe({
      next: (ids) => {
        this.ordre.set(ids);
        this.ids.set(new Set(ids));
      },
      // Une liste d'envies indisponible n'est pas une panne d'application :
      // les cœurs restent vides, et le reste de la boutique fonctionne.
      error: () => {
        this.ordre.set([]);
        this.ids.set(new Set());
      },
    });
  }

  private poser(produitId: number, present: boolean): void {
    const copie = new Set(this.ids());
    if (present) {
      copie.add(produitId);
      this.ordre.update((l) => [produitId, ...l.filter((x) => x !== produitId)]);
    } else {
      copie.delete(produitId);
      this.ordre.update((l) => l.filter((x) => x !== produitId));
    }
    this.ids.set(copie);
  }
}
