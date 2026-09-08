import { HttpErrorResponse } from '@angular/common/http';

/**
 * Ce que le serveur répond quand il refuse.
 *
 * <p>Le corps est toujours de cette forme — c'est
 * {@code GestionnaireErreursGlobal} qui le produit, pour toutes les routes.</p>
 */
interface RefusServeur {
  readonly code?: string;
  readonly message?: string;

  /**
   * Le détail, champ par champ.
   *
   * <pre>
   * { "motDePasse": "Le mot de passe doit contenir entre 10 et 200 caractères." }
   * </pre>
   */
  readonly champs?: Record<string, string>;
}

/**
 * Traduit un refus du serveur en une phrase qu'on peut montrer.
 *
 * <h2>🎯 Le détail par champ passe AVANT le message général</h2>
 *
 * <p>Sur une erreur de validation, le serveur renvoie deux choses : un
 * {@code message} générique — « Certains champs sont invalides. » — et un objet
 * {@code champs} qui dit <b>lequel</b> et <b>pourquoi</b>.</p>
 *
 * <p>⚠️ Quatre écrans de la boutique ne lisaient que le premier, c'est-à-dire
 * la moins utile des deux phrases. Sur l'inscription, cela rendait la création
 * de compte <b>impossible en pratique</b> : le visiteur voyait « Certains
 * champs sont invalides », corrigeait au hasard, et renonçait. Il ne pouvait
 * pas deviner qu'il manquait deux caractères à son mot de passe.</p>
 *
 * <h2>⚠️ Les messages du serveur sont repris TELS QUELS</h2>
 *
 * <p>Les réécrire ici les ferait diverger au premier changement de règle : le
 * jour où le minimum passe de dix à douze, le serveur le dira et la boutique
 * continuerait d'annoncer dix.</p>
 *
 * <h2>Une fonction partagée, et pas quatre copies</h2>
 *
 * <p>C'est une copie de trop qui a produit le défaut d'origine : l'écran
 * exigeait huit caractères là où l'API en demandait dix, parce que la règle
 * avait été recopiée au lieu d'être demandée.</p>
 *
 * @param defaut ce qu'on dit quand le serveur n'explique rien — propre à
 *               l'écran, parce que « l'opération a échoué » ne dit rien à
 *               personne
 */
export function messageErreur(e: unknown, defaut: string): string {
  if (!(e instanceof HttpErrorResponse)) {
    return defaut;
  }

  // ⚠️ Le cas le plus fréquent sur le terrain, et ce n'est PAS une panne du
  //    serveur : une connexion coupée en pleine rue. Le dire comme tel évite
  //    de faire chercher du côté de l'application.
  if (e.status === 0) {
    return 'Pas de connexion. Réessayez dans un instant.';
  }

  const corps = e.error as RefusServeur | null;

  const champs = corps?.champs;
  if (champs) {
    const detail = Object.values(champs).filter((v) => typeof v === 'string' && v.length > 0);
    if (detail.length > 0) {
      return detail.join(' ');
    }
  }

  return corps?.message ?? defaut;
}
