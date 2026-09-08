/**
 * La configuration Firebase de la boutique.
 *
 * <h2>⚠️ Rien ici n'est un secret, et rien ici ne doit en devenir un</h2>
 *
 * Ces valeurs partent dans le paquet JavaScript, donc dans le navigateur de
 * tout visiteur. Ce ne sont pas des clés au sens courant : ce sont des
 * **identifiants de projet**. La `apiKey` de Firebase, en particulier, désigne
 * le projet — elle n'autorise rien par elle-même.
 *
 * Ce qui EST un secret — la clé de compte de service, celle qui permet
 * d'*envoyer* — vit dans les réglages d'Azure, côté serveur, et n'a jamais
 * traversé ce dépôt.
 *
 * <h2>La clé VAPID vaut pour les deux applications web</h2>
 *
 * Le certificat push est attaché au **projet**, pas à l'application : la
 * boutique et le back-office partagent le même `messagingSenderId`, donc la
 * même clé. En générer une par application ne casserait rien, mais n'apporte
 * rien non plus.
 */
export const firebase = {
  apiKey: 'AIzaSyA5raZbvm3mr_MXL3gXsmHMsc1tvCn4TrU',
  authDomain: 'garah-project.firebaseapp.com',
  projectId: 'garah-project',
  storageBucket: 'garah-project.firebasestorage.app',
  messagingSenderId: '215742260538',
  // Celui de l'application « garah-web ». Le back-office a le sien.
  appId: '1:215742260538:web:1fd8062ea4addb2fc49c03',
};

/** La clé publique du certificat push web. */
export const cleVapid =
  'BJcq8tKSf81QjiT6FQ9QNuVw1qvKL_1fdYnHDUX-7u-H4u16eIhy-J-XYSGJZ6YloI8mL7a5Jh5xTHtz-Bc6Eww';
