import { HttpEvent, HttpHandlerFn, HttpRequest } from '@angular/common/http';
import { InjectionToken, inject } from '@angular/core';
import { Observable } from 'rxjs';

/**
 * L'adresse de l'API. Fournie à l'amorçage, jamais lue ailleurs.
 *
 * <p>Un jeton d'injection plutôt qu'une constante importée : le jour où la
 * boutique tourne en préproduction, seule la valeur fournie change.</p>
 */
export const CONFIGURATION_API = new InjectionToken<{ baseUrl: string }>('CONFIGURATION_API');

/**
 * L'intercepteur unique de la boutique.
 *
 * <h2>Ce qu'il fait, et pourquoi il est seul à le faire</h2>
 *
 * <p>Trois choses que le backend <b>impose</b> et qu'aucun composant ne doit
 * refaire :</p>
 *
 * <ol>
 *   <li>l'URL absolue — les écrans écrivent {@code /api/produits}, l'API vit
 *       ailleurs ;</li>
 *   <li>l'en-tête {@code X-Garah-Client} sur <b>toute</b> requête ;</li>
 *   <li>{@code withCredentials}, sans quoi le cookie de session ne part
 *       jamais.</li>
 * </ol>
 *
 * <p>⚠️ Le cookie de rafraîchissement est en {@code SameSite=None} : le
 * navigateur l'enverrait donc aussi depuis une page tierce. Le backend exige
 * un en-tête personnalisé sur {@code /rafraichir} et {@code /deconnexion}
 * précisément pour forcer un préflight CORS que seules nos origines passent.
 * <b>Sans cet en-tête, la session meurt au bout de quinze minutes avec un 403,
 * et rien avant ne le laisse deviner.</b></p>
 *
 * <h2>Ce qu'il ne fait PAS, contrairement à celui du back-office</h2>
 *
 * <p>🎯 <b>Aucun rafraîchissement automatique de jeton ici.</b> La vitrine est
 * ouverte : la plupart des requêtes partent sans session, et un {@code 401}
 * sur une route publique ne veut pas dire « jeton expiré ». Rejouer un
 * rafraîchissement à chaque refus ferait, sur une connexion lente, une requête
 * inutile de plus par produit consulté.</p>
 *
 * <p>Le rafraîchissement appartient au service de session, qui sait s'il y a
 * une session à rafraîchir. Voir {@code ServiceSession}.</p>
 */
export function intercepteurApi(
  requete: HttpRequest<unknown>,
  suite: HttpHandlerFn,
): Observable<HttpEvent<unknown>> {
  const config = inject(CONFIGURATION_API);

  // Un appel vers autre chose que notre API — une image sur Backblaze, une
  // police — ne doit recevoir NI notre jeton NI nos cookies. Les y joindre les
  // enverrait à un tiers.
  if (!estAppelApi(requete.url, config.baseUrl)) {
    return suite(requete);
  }

  const jeton = jetonCourant();

  return suite(
    requete.clone({
      url: requete.url.startsWith('/') ? `${config.baseUrl}${requete.url}` : requete.url,
      withCredentials: true,
      setHeaders: {
        'X-Garah-Client': '1',
        ...(jeton ? { Authorization: `Bearer ${jeton}` } : {}),
      },
    }),
  );
}

/**
 * Le jeton d'accès courant, ou {@code null}.
 *
 * <p>⚠️ <b>En mémoire, jamais dans {@code localStorage}.</b> Un jeton rangé
 * là s'y lit depuis n'importe quel script de la page — c'est le seul secret
 * que la boutique manipule, et il vit quinze minutes.</p>
 *
 * <p>Posé par {@code ServiceSession} à la connexion. Une variable de module
 * plutôt qu'un service injecté : l'intercepteur s'exécute hors de tout
 * contexte d'injection fiable pour un état aussi simple.</p>
 */
let jetonEnMemoire: string | null = null;

export function poserJeton(jeton: string | null): void {
  jetonEnMemoire = jeton;
}

function jetonCourant(): string | null {
  return jetonEnMemoire;
}

/**
 * Cet appel va-t-il vers NOTRE API ?
 *
 * <p>⚠️ Le test sur {@code base} est gardé par {@code base !== ''}, et ce
 * n'est pas de la prudence : en développement la base est <b>vide</b>, pour
 * que les requêtes restent relatives et passent par le proxy. Or
 * {@code "https://f003.backblazeb2.com/…".startsWith("")} vaut
 * <b>vrai</b> — sans cette garde, l'intercepteur joindrait le jeton et les
 * cookies de session à chaque image chargée depuis Backblaze.</p>
 *
 * <p>C'est le genre de fuite qui ne casse rien : les images s'afficheraient,
 * et le jeton partirait chez un tiers à chaque photo de produit.</p>
 */
function estAppelApi(url: string, base: string): boolean {
  return url.startsWith('/api/') || (base !== '' && url.startsWith(base));
}
