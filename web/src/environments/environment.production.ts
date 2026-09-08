/**
 * L'environnement de PRODUCTION.
 *
 * L'API est sur Azure App Service (region France Central). Cette valeur est la
 * SEULE difference entre les deux fichiers : tout le reste du code ignore ou
 * vit l'API — c'est l'intercepteur, et lui seul, qui la connait.
 */
export const environnement = {
  production: true,
  urlApi: 'https://garah-api-anfeapebbth7h7an.francecentral-01.azurewebsites.net',
};
