import { HttpClient } from '@angular/common/http';
import { Injectable, computed, inject, signal } from '@angular/core';
import { Observable, catchError, map, of, tap } from 'rxjs';

import { poserJeton } from '../api/intercepteur-api';
import { PanierLocal } from './panier-local';

/**
 * Ce que le serveur renvoie à la connexion.
 *
 * <h2>⚠️ Cette interface DÉCRIVAIT une réponse qui n'existe pas</h2>
 *
 * <p>Elle déclarait `jetonAcces`, `utilisateurId`, `nom` et `email` à la
 * racine. Le serveur envoie `jeton` et un objet `utilisateur` imbriqué — et
 * l'a toujours fait : c'est le contrat que le back-office lit correctement.</p>
 *
 * <p>Rien ne le signalait. TypeScript ne vérifie <b>rien</b> à l'exécution :
 * `post&lt;ResultatConnexion&gt;` est une promesse faite au compilateur, pas
 * un contrôle. Lire un champ absent rend `undefined`, sans erreur.</p>
 *
 * <p>Le résultat : `poserJeton(undefined)` — donc aucun jeton — et un
 * utilisateur dont tous les champs valaient `undefined`. L'objet n'étant pas
 * `null`, `connecte()` répondait <b>vrai</b> : l'application se croyait
 * connectée, affichait un nom vide, et tous ses appels partaient sans
 * autorisation.</p>
 *
 * <p>Le mobile portait exactement le même désaccord, aux mêmes noms.</p>
 */
interface ResultatConnexion {
  readonly jeton: string;
  readonly typeJeton: string;
  readonly expireDansSecondes: number;
  readonly utilisateur: {
    readonly id: number;
    readonly nom: string;
    readonly email: string;
    /** `CLIENT`, `RESPONSABLE`, `ADMIN`, `SUPER_ADMIN`. */
    readonly type: string;
  };
}

/**
 * Indice de session — et rien d'autre.
 *
 * <p>⚠️ Ce n'est <b>pas</b> le jeton. Le jeton vit en mémoire (voir
 * {@code intercepteur-api}) ; ceci n'est qu'un drapeau qui dit « ce navigateur
 * a déjà eu une session », pour savoir s'il vaut la peine de tenter un
 * rafraîchissement au démarrage. Un visiteur qui n'a jamais ouvert de compte
 * n'appelle donc jamais le réseau pour rien.</p>
 */
const INDICE = 'garah.session';

@Injectable({ providedIn: 'root' })
export class ServiceSession {
  private readonly http = inject(HttpClient);
  private readonly panierLocal = inject(PanierLocal);

  private readonly utilisateur =
    signal<{ id: number; nom: string; email: string; type: string } | null>(null);

  readonly connecte = computed(() => this.utilisateur() !== null);
  readonly nom = computed(() => this.utilisateur()?.nom ?? null);

  /**
   * Le compte ouvert ici est-il bien celui d'un CLIENT ?
   *
   * <p>⚠️ La boutique ne portait pas le type du compte, donc ne pouvait pas se
   * poser la question. Son garde ne vérifiait que « connecté » : une session
   * d'administration y ouvrait « mes commandes », « mes retours », « mon
   * profil » — des écrans qui n'ont rien à lui montrer, puisqu'un
   * administrateur n'a pas de ligne `client`.</p>
   *
   * <p>Aucune donnée n'était exposée : ce sont ses propres écrans, vides. Mais
   * un écran vide se lit comme une panne, et l'on cherche la commande perdue
   * plutôt que le compte utilisé.</p>
   */
  readonly estClient = computed(() => this.utilisateur()?.type === 'CLIENT');

  /** Qui je suis, cote serveur. Sert a distinguer MES messages dans un fil. */
  readonly utilisateurId = computed(() => this.utilisateur()?.id ?? null);

  /** Vrai tant qu'on ne sait pas encore si une session existe. */
  readonly enCoursDeRestauration = signal(false);

  connecter(email: string, motDePasse: string): Observable<boolean> {
    return this.http
      .post<ResultatConnexion>('/api/auth/connexion', { email, motDePasse })
      .pipe(
        tap((r) => this.ouvrir(r)),
        // La fusion suit la connexion, jamais l'inverse : elle a besoin du
        // jeton que `ouvrir` vient de poser.
        tap(() => this.fusionnerLePanier()),
        map(() => true),
        catchError(() => of(false)),
      );
  }

  /**
   * Tente de reprendre une session au démarrage.
   *
   * <p>⚠️ N'appelle le réseau que si l'indice existe. Sans cette garde, chaque
   * visiteur anonyme paierait un aller-retour au chargement de l'accueil —
   * sur une connexion mobile, c'est la première seconde de la visite.</p>
   */
  restaurer(): Observable<boolean> {
    if (!localStorage.getItem(INDICE)) {
      return of(false);
    }

    this.enCoursDeRestauration.set(true);

    return this.http.post<ResultatConnexion>('/api/auth/rafraichir', {}).pipe(
      tap((r) => this.ouvrir(r)),
      map(() => true),
      catchError(() => {
        // Un échec veut dire « plus de session », pas « panne » : on efface
        // l'indice pour ne pas réessayer à chaque page.
        this.fermer();
        return of(false);
      }),
      tap(() => this.enCoursDeRestauration.set(false)),
    );
  }

  deconnecter(): Observable<void> {
    return this.http.post<void>('/api/auth/deconnexion', {}).pipe(
      catchError(() => of(undefined)),
      tap(() => {
        this.fermer();
        // ⚠️ Sur un poste partagé, le panier d'un visiteur ne doit pas
        //    accueillir le suivant.
        this.panierLocal.vider();
      }),
      map(() => undefined),
    );
  }

  /**
   * Reprend le panier constitué avant la connexion.
   *
   * <p>Les écarts sont ignorés ici : c'est l'écran du panier qui les annonce,
   * en relisant le panier serveur. Les traiter au vol, pendant une
   * redirection, les ferait disparaître avant d'être lus.</p>
   */
  private fusionnerLePanier(): void {
    const lignes = this.panierLocal.pourFusion();
    if (lignes.length === 0) {
      return;
    }

    this.http.post('/api/panier/fusion', { lignes }).subscribe({
      next: () => this.panierLocal.vider(),
      error: () => {
        // Le panier local RESTE : la fusion se retentera à la prochaine
        // connexion. L'effacer sur un échec réseau perdrait le panier.
      },
    });
  }

  private ouvrir(r: ResultatConnexion): void {
    poserJeton(r.jeton);
    this.utilisateur.set({
      id: r.utilisateur.id,
      nom: r.utilisateur.nom,
      email: r.utilisateur.email,
      type: r.utilisateur.type,
    });
    localStorage.setItem(INDICE, '1');
  }

  private fermer(): void {
    poserJeton(null);
    this.utilisateur.set(null);
    localStorage.removeItem(INDICE);
    this.enCoursDeRestauration.set(false);
  }
}
