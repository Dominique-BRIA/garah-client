import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { map } from 'rxjs';

import { ServiceSession } from '../../services/session';

/**
 * Le garde des quatre ecrans qui touchent au compte.
 *
 * <h2>Il TENTE une restauration avant de refuser</h2>
 *
 * <p>Un visiteur qui recharge « mes commandes » a une session valide cote
 * serveur, mais rien en memoire : le jeton n'y survit pas. Refuser tout de
 * suite le renverrait a la connexion alors qu'il est connecte — le genre de
 * defaut qu'on met des jours a relier a un rechargement.</p>
 *
 * <p>La restauration n'appelle le reseau que si l'indice de session existe :
 * un visiteur anonyme est refuse immediatement, sans aller-retour.</p>
 */
export const gardeSession: CanActivateFn = (_route, etat) => {
  const session = inject(ServiceSession);
  const router = inject(Router);

  if (session.connecte()) {
    return true;
  }

  return session.restaurer().pipe(
    map((ouverte) =>
      ouverte
        ? true
        : // On garde la destination : apres la connexion, on revient ICI, pas
          // sur l'accueil. Se retrouver ailleurs qu'ou l'on allait fait
          // recommencer toute la navigation.
          router.createUrlTree(['/connexion'], { queryParams: { suite: etat.url } }),
    ),
  );
};
