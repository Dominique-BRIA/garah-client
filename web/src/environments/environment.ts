/**
 * L'environnement de DEVELOPPEMENT.
 *
 * 🎯 L'URL est VIDE, et c'est deliberе : les requetes restent RELATIVES
 * (`/api/produits`), donc elles partent vers le serveur de developpement, qui
 * les transmet a Azure via `proxy.conf.json`.
 *
 * ⚠️ Sans ce detour, le navigateur appelle Azure directement depuis
 *    http://localhost:4300 — et le preflight CORS repond 403, parce que cette
 *    origine n'est pas dans GARAH_CORS_ORIGINS. Le symptome a l'ecran est
 *    « Pas de connexion », qui fait chercher du cote du reseau alors que le
 *    serveur repond parfaitement.
 *
 *    Le proxy evite d'avoir a declarer chaque poste de developpement cote
 *    serveur.
 *
 * ⚠️ Les donnees restent celles de PRODUCTION. Une commande passee ici est une
 *    vraie commande.
 *
 * ⚠️ CE FICHIER NE DOIT JAMAIS PARTIR EN PRODUCTION.
 *
 *    C'est `angular.json`, par le `fileReplacements` de sa configuration
 *    `production`, qui le remplace par `environment.production.ts`. Sans cette
 *    ligne, la boutique deployee garde `urlApi: ''` : les requetes partent en
 *    RELATIF vers son propre domaine, la reecriture SPA les renvoie vers
 *    index.html, et l'application recoit du HTML la ou elle attend du JSON.
 *
 *    Le symptome est trompeur au possible : aucune erreur reseau, aucun refus
 *    CORS, juste des ecrans vides. On cherche du cote des origines autorisees
 *    pendant que la boutique n'a JAMAIS appele l'API. C'est arrive.
 *
 *    Pour verifier apres un `ng build`, le paquet livre DOIT contenir
 *    l'adresse d'Azure :
 *
 *        grep -c garah-api dist/garah-boutique/browser/main-*.js
 */
export const environnement = {
  production: false,
  urlApi: '',
};
