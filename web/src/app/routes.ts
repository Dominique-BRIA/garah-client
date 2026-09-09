import { Routes } from '@angular/router';

import { gardeSession } from './compte/garde';

/**
 * Les routes de la boutique.
 *
 * <h2>Tout est public, sauf quatre écrans</h2>
 *
 * <p>🎯 C'est l'inverse du back-office, où la coque porte un garde et où
 * chaque écran en hérite. Ici la vitrine est ouverte (D-07) : le garde se pose
 * <b>écran par écran</b>, sur les quatre qui touchent au compte.</p>
 *
 * <p>Le risque du choix inverse serait pire : un garde global obligerait à
 * l'ouvrir explicitement pour chaque page publique, et un oubli rendrait une
 * fiche produit inaccessible aux visiteurs — sans erreur, juste une
 * redirection vers la connexion.</p>
 */
export const routes: Routes = [
  {
    path: '',
    loadComponent: () => import('./accueil/accueil').then((m) => m.Accueil),
  },
  {
    path: 'catalogue',
    loadComponent: () => import('./catalogue/catalogue').then((m) => m.Catalogue),
  },

  // ⚠️ AVANT 'produit/:slug' n'aurait aucun sens ici : il n'y a pas de segment
  //    littéral qui pourrait être pris pour un slug. Mais le jour où l'on
  //    ajoute 'produit/nouveau' ou 'produit/comparer', il faudra le placer
  //    au-dessus — c'est le piège qui a déjà mordu deux fois côté back-office.
  {
    path: 'produit/:slug',
    loadComponent: () => import('./produit/produit').then((m) => m.Produit),
  },

  // Le suivi sans compte. Deux routes : '/suivi' seul affiche le champ,
  // '/suivi/GRH…' lance la recherche — arriver par un lien partagé ne doit pas
  // obliger à resaisir ce que le lien contenait déjà.
  {
    path: 'suivi',
    loadComponent: () => import('./suivi/suivi').then((m) => m.Suivi),
  },
  {
    path: 'suivi/:numero',
    loadComponent: () => import('./suivi/suivi').then((m) => m.Suivi),
  },

  {
    path: 'connexion',
    loadComponent: () => import('./compte/connexion').then((m) => m.Connexion),
  },
  {
    path: 'inscription',
    loadComponent: () => import('./compte/inscription').then((m) => m.Inscription),
  },

  /*
   * ⚠️ PUBLIQUE, et elle DOIT l'etre : on arrive ici depuis un courriel, sans
   *    session. La garder derriere le garde renverrait vers la connexion, et
   *    le jeton serait perdu en chemin.
   *
   * ⚠️ Cette route MANQUAIT. Le lien de confirmation se construit a partir de
   *    GARAH_URL_VERIFICATION, et le nom invitait a la faire pointer ici —
   *    mais la regle de repli (** -> accueil) attrapait la visite et le jeton
   *    disparaissait EN SILENCE. Le courriel partait, le lien ouvrait bien la
   *    boutique, l'accueil s'affichait : le client se croyait confirme, et
   *    decouvrait le refus des semaines plus tard, au paiement.
   */
  {
    path: 'verification',
    loadComponent: () => import('./compte/verification').then((m) => m.Verification),
  },

  /*
   * Le panier est PUBLIC, et ce n'est pas un oubli.
   *
   * 🎯 Un visiteur remplit son panier sans compte — il vit dans le navigateur.
   *    Exiger la connexion pour le CONSULTER ferait fuir au premier
   *    « Ajouter », et c'est justement ce qu'on a voulu éviter.
   *
   *    La connexion arrive au moment de commander, pas avant.
   */
  {
    path: 'panier',
    loadComponent: () => import('./panier/panier').then((m) => m.Panier),
  },

  // --- Ce qui exige un compte ---
  {
    path: 'commande',
    canActivate: [gardeSession],
    loadComponent: () => import('./commande/commande').then((m) => m.Commande),
  },
  {
    path: 'paiement/:id',
    canActivate: [gardeSession],
    loadComponent: () => import('./commande/paiement').then((m) => m.Paiement),
  },
  {
    path: 'mes-commandes',
    canActivate: [gardeSession],
    loadComponent: () => import('./compte/mes-commandes').then((m) => m.MesCommandes),
  },
  /**
   * Le detail d'une commande.
   *
   * ⚠️ L'URL porte l'IDENTIFIANT, jamais le code de retrait. Le code est un
   *    secret partage : dans une URL il finirait dans les journaux du
   *    serveur, l'historique du navigateur et l'en-tete Referer du
   *    premier lien clique. Le numero de SUIVI, lui, a sa place dans une
   *    URL — il se partage, c'est son role.
   */
  {
    path: 'mes-commandes/:id',
    canActivate: [gardeSession],
    loadComponent: () =>
      import('./compte/detail-commande').then((m) => m.DetailCommandeEcran),
  },
  {
    path: 'ma-liste',
    canActivate: [gardeSession],
    loadComponent: () => import('./compte/favoris').then((m) => m.Favoris),
  },
  {
    path: 'mes-reclamations',
    canActivate: [gardeSession],
    loadComponent: () => import('./compte/reclamations').then((m) => m.Reclamations),
  },
  /**
   * Mes retours.
   *
   * Le formulaire s'ouvre avec `?commande=<id>`, depuis le detail d'une
   * commande. Sans ce parametre, l'ecran n'affiche que la liste — on peut
   * suivre ses retours sans en demander un nouveau.
   */
  {
    path: 'mes-retours',
    canActivate: [gardeSession],
    loadComponent: () => import('./compte/retours').then((m) => m.Retours),
  },
  {
    path: 'mes-discussions',
    canActivate: [gardeSession],
    loadComponent: () => import('./compte/discussions').then((m) => m.Discussions),
  },
  {
    path: 'mes-discussions/:id',
    canActivate: [gardeSession],
    loadComponent: () => import('./compte/discussion').then((m) => m.Discussion),
  },
  {
    path: 'profil',
    canActivate: [gardeSession],
    loadComponent: () => import('./compte/profil').then((m) => m.Profil),
  },

  { path: '**', redirectTo: '' },
];
