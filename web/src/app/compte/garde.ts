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
 *
 * <h2>⚠️ Il exige un compte CLIENT, pas seulement une session</h2>
 *
 * <p>Il ne verifiait que « connecte ». Une session d'ADMINISTRATION ouvrait
 * donc « mes commandes », « mes retours », « mon profil » — des ecrans qui
 * n'ont rien a lui montrer, puisqu'un administrateur n'a pas de ligne
 * `client`.</p>
 *
 * <p>Aucune donnee n'etait exposee : ce sont ses propres ecrans, vides. Mais un
 * ecran vide se lit comme une panne, et l'on cherche la commande perdue
 * plutot que le compte utilise. C'est le miroir du defaut repare cote
 * back-office par D-33.</p>
 *
 * <p>⚠️ Le refus renvoie a l'ACCUEIL, pas a la connexion : proposer de se
 * connecter a quelqu'un qui l'est deja est une impasse — il recommencerait,
 * reussirait, et reviendrait au meme refus.</p>
 */
export const gardeSession: CanActivateFn = (_route, etat) => {
  const session = inject(ServiceSession);
  const router = inject(Router);

  // On garde la destination : apres la connexion, on revient ICI, pas sur
  // l'accueil. Se retrouver ailleurs qu'ou l'on allait fait recommencer toute
  // la navigation.
  const versLaConnexion = () =>
    router.createUrlTree(['/connexion'], { queryParams: { suite: etat.url } });

  const verdict = () => (session.estClient() ? true : router.createUrlTree(['/']));

  if (session.connecte()) {
    return verdict();
  }

  return session.restaurer().pipe(
    map((ouverte) => (ouverte ? verdict() : versLaConnexion())),
  );
};
