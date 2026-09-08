import { ApplicationConfig, provideZonelessChangeDetection } from '@angular/core';
import { provideBrowserGlobalErrorListeners } from '@angular/core';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { provideRouter, withComponentInputBinding, withInMemoryScrolling } from '@angular/router';

import { CONFIGURATION_API, intercepteurApi } from '../api/intercepteur-api';
import { environnement } from '../environments/environment';
import { routes } from './routes';

export const configuration: ApplicationConfig = {
  providers: [
    provideBrowserGlobalErrorListeners(),

    // Zoneless, comme le back-office — et ici la boutique ne charge même pas
    // `zone.js` en polyfill. Une trentaine de kilo-octets compressés en moins
    // sur exactement la connexion où ils comptent.
    provideZonelessChangeDetection(),

    provideRouter(
      routes,
      withComponentInputBinding(),

      // ⚠️ Sans ceci, ouvrir une fiche produit depuis le milieu du catalogue
      //    laisse la page à la même hauteur : le visiteur arrive au milieu du
      //    descriptif et croit que rien ne s'est passé.
      //
      //    `anchorScrolling` sert au retour arrière : on revient là où on
      //    était dans la liste, pas en haut.
      withInMemoryScrolling({
        scrollPositionRestoration: 'enabled',
        anchorScrolling: 'enabled',
      }),
    ),

    // 🎯 L'intercepteur est le SEUL endroit qui connaît l'URL de l'API, pose
    //    l'en-tête X-Garah-Client et joint les cookies. Un appel HttpClient
    //    qui le contournerait perdrait les trois d'un coup — et le troisième
    //    ne se verrait qu'au bout de quinze minutes, par un 403.
    provideHttpClient(withInterceptors([intercepteurApi])),

    { provide: CONFIGURATION_API, useValue: { baseUrl: environnement.urlApi } },

    /*
     * ⚠️ PAS de `provideAppInitializer` qui restaure la session, contrairement
     *    au back-office.
     *
     *    Là-bas, tout écran exige une session : bloquer le démarrage le temps
     *    de la restaurer évite une page blanche. Ici, la vitrine est OUVERTE —
     *    la majorité des visiteurs n'ont pas de compte, et les faire attendre
     *    un appel réseau qui ne les concerne pas retarderait l'accueil pour
     *    rien.
     *
     *    La session se restaure donc en arrière-plan, et les rares écrans qui
     *    l'exigent l'attendent eux-mêmes.
     */
  ],
};
