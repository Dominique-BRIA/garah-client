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
 */
export const environnement = {
  production: false,
  urlApi: '',
};
