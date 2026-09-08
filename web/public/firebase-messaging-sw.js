/*
 * L'agent de service des notifications.
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * 🎯 IL DOIT S'APPELER EXACTEMENT `firebase-messaging-sw.js`
 *    ET VIVRE À LA RACINE DU DOMAINE.
 * ═══════════════════════════════════════════════════════════════════════════
 * Firebase l'enregistre lui-même, sous ce nom, sur `/`. Le renommer ou le
 * ranger dans un sous-dossier casse les notifications reçues quand l'onglet
 * est fermé — SANS AUCUN MESSAGE D'ERREUR. `getToken()` réussit, l'abonnement
 * a l'air posé, et rien n'arrive jamais.
 *
 * Il est dans `public/`, dont Angular verse le contenu à la racine du build.
 *
 * ⚠️ CE FICHIER NE PASSE PAS PAR LE COMPILATEUR.
 *    Pas de TypeScript, pas d'import de module, pas de jetons de la charte.
 *    C'est du JavaScript brut exécuté par le navigateur, hors de l'application.
 *    Les valeurs y sont donc RECOPIÉES depuis src/environments/firebase.ts, et
 *    doivent y rester identiques.
 *
 * ⚠️ LA VERSION DES SCRIPTS EST FIGÉE.
 *    `importScripts` charge la variante « compat » depuis le CDN de Google.
 *    Une version flottante casserait les notifications un matin, sans qu'aucun
 *    commit n'ait bougé — et on chercherait l'erreur dans son propre code.
 */

importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyA5raZbvm3mr_MXL3gXsmHMsc1tvCn4TrU',
  authDomain: 'garah-project.firebaseapp.com',
  projectId: 'garah-project',
  storageBucket: 'garah-project.firebasestorage.app',
  messagingSenderId: '215742260538',
  appId: '1:215742260538:web:1fd8062ea4addb2fc49c03',
});

const messagerie = firebase.messaging();

/*
 * Ce qui arrive quand l'onglet est fermé ou en arrière-plan.
 *
 * ⚠️ Le serveur envoie un bloc `notification` ET un bloc `data`. Firefox et
 *    Chrome affichent alors la bannière EUX-MÊMES : redessiner une notification
 *    ici en donnerait DEUX pour le même événement. On ne prend donc la main que
 *    si le message n'a pas de bloc `notification`.
 */
messagerie.onBackgroundMessage((charge) => {
  if (charge.notification) {
    return;
  }

  const donnees = charge.data || {};
  self.registration.showNotification(donnees.titre || 'GARAH', {
    body: donnees.corps || '',
    icon: '/favicon.svg',
    // Le regroupement par type : trois messages d'un même conseiller ne
    // doivent pas empiler trois bannières identiques.
    tag: donnees.type || 'garah',
    data: donnees,
  });
});

/*
 * Ce qui se passe quand on touche la bannière.
 *
 * 🎯 On RÉUTILISE l'onglet déjà ouvert plutôt que d'en ouvrir un second.
 *    Sans cette recherche, chaque notification touchée ajoute un onglet, et on
 *    se retrouve avec six GARAH ouverts sans savoir lequel regarder.
 */
self.addEventListener('notificationclick', (evenement) => {
  evenement.notification.close();

  const donnees = evenement.notification.data || {};
  const chemin = destination(donnees.type, donnees.id);

  evenement.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((onglets) => {
      for (const onglet of onglets) {
        if ('focus' in onglet) {
          onglet.navigate(chemin);
          return onglet.focus();
        }
      }
      return self.clients.openWindow(chemin);
    }),
  );
});

/*
 * Le serveur envoie un TYPE et un identifiant ; c'est le client qui décide de
 * l'écran.
 *
 * ⚠️ L'inverse — une route toute faite dans le message — figerait la
 *    navigation du site dans le backend : renommer un chemin casserait les
 *    notifications déjà parties, qui vivent parfois plusieurs jours sur un
 *    téléphone éteint.
 */
function destination(type, id) {
  switch (type) {
    case 'COMMANDE':
      return id ? '/mes-commandes/' + id : '/mes-commandes';
    case 'CONVERSATION':
    case 'NEGOCIATION':
      return id ? '/mes-discussions/' + id : '/mes-discussions';
    default:
      return '/';
  }
}
