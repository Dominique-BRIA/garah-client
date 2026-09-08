/**
 * L'environnement de DEVELOPPEMENT.
 *
 * ⚠️ Vise l'API DEPLOYEE, pas un serveur local — comme le back-office.
 *
 *    Consequence a connaitre : les donnees que l'on voit en developpant sont
 *    celles de PRODUCTION. Une commande passee ici est une vraie commande.
 *
 *    Pour viser un Spring Boot local, remplacer par http://localhost:8080 et
 *    ajouter cette origine a GARAH_CORS_ORIGINS cote serveur.
 */
export const environnement = {
  production: false,
  urlApi: 'https://garah-api-anfeapebbth7h7an.francecentral-01.azurewebsites.net',
};
