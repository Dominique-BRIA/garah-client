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
  {
    path: 'profil',
    canActivate: [gardeSession],
    loadComponent: () => import('./compte/profil').then((m) => m.Profil),
  },

  { path: '**', redirectTo: '' },
];
