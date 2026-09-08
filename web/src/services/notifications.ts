import { HttpClient } from '@angular/common/http';
import { Injectable, computed, effect, inject, signal } from '@angular/core';

import { cleVapid, firebase } from '../environments/firebase';
import { ServiceSession } from './session';

/** Ce que le navigateur nous laisse faire, en un mot. */
export type EtatNotifications = 'indisponible' | 'a-demander' | 'refuse' | 'actif';

/**
 * Les notifications du navigateur.
 *
 * <h2>🎯 On ne demande JAMAIS la permission au chargement</h2>
 *
 * <p>Une demande qui surgit avant qu'on ait rien fait est refusée dans la
 * majorité des cas — et un refus est <b>définitif</b> : le navigateur ne
 * repose plus la question, et l'utilisateur doit aller la débloquer dans ses
 * réglages, ce que personne ne fait. On attend donc un geste explicite.</p>
 *
 * <h2>⚠️ Firebase est chargé À LA DEMANDE</h2>
 *
 * <p>Un {@code import} statique le mettrait dans le paquet initial — près de
 * 80 ko pour une fonctionnalité que la plupart des visiteurs n'activeront
 * jamais. La boutique dépasse déjà son budget ; l'import dynamique le garde
 * dans un morceau à part, chargé au premier clic.</p>
 *
 * <h2>⚠️ Ce qui ne marchera pas, et qu'il faut DIRE</h2>
 *
 * <ul>
 *   <li><b>Safari sur iPhone</b> n'accepte les notifications web que si le
 *       site a été ajouté à l'écran d'accueil. Ce n'est pas contournable, et
 *       le taire ferait passer une limite d'Apple pour une panne de GARAH.</li>
 *   <li><b>En développement</b>, l'agent de service est servi par le
 *       mandataire : l'abonnement échoue. C'est normal, et sans conséquence
 *       une fois déployé.</li>
 * </ul>
 */
@Injectable({ providedIn: 'root' })
export class ServiceNotifications {
  private readonly http = inject(HttpClient);
  private readonly session = inject(ServiceSession);

  private readonly permission = signal<NotificationPermission | null>(lirePermission());
  private readonly abonne = signal(false);
  private readonly enCours = signal(false);

  /** Le jeton déclaré au serveur, pour savoir lequel retirer. */
  private jeton: string | null = null;

  readonly occupe = this.enCours.asReadonly();

  readonly etat = computed<EtatNotifications>(() => {
    const p = this.permission();
    if (p === null) {
      return 'indisponible';
    }
    if (p === 'denied') {
      return 'refuse';
    }
    return p === 'granted' && this.abonne() ? 'actif' : 'a-demander';
  });

  constructor() {
    // Le jeton appartient au COMPTE, pas au navigateur.
    //
    // ⚠️ Sur un poste partagé — un cybercafé, un ordinateur de famille —
    //    garder l'abonnement après une déconnexion enverrait au suivant les
    //    notifications du précédent, y compris « votre marchandise vous
    //    attend », qui désigne un colis qui n'est pas le sien.
    effect(() => {
      if (!this.session.connecte()) {
        void this.retirer();
      }
    });
  }

  /**
   * Active les notifications, sur un geste explicite.
   *
   * <p>Rend un message d'explication en cas d'échec, ou {@code null} si tout
   * s'est bien passé. Un bouton qui ne fait rien et ne dit rien se clique
   * trois fois avant qu'on renonce.</p>
   */
  async activer(): Promise<string | null> {
    if (this.enCours()) {
      return null;
    }
    if (!('Notification' in window) || !('serviceWorker' in navigator)) {
      return 'Ce navigateur ne gère pas les notifications.';
    }
    if (!this.session.connecte()) {
      return 'Connectez-vous pour recevoir des notifications.';
    }

    this.enCours.set(true);
    try {
      const accord = await Notification.requestPermission();
      this.permission.set(accord);

      if (accord !== 'granted') {
        // ⚠️ Un refus est DÉFINITIF côté navigateur : on le dit, plutôt que de
        //    laisser rappuyer sur un bouton qui ne redemandera jamais.
        return 'Notifications refusées. Vous pouvez les réactiver dans les '
          + 'réglages de votre navigateur, à la ligne de ce site.';
      }

      const { initializeApp } = await import('firebase/app');
      const { getMessaging, getToken, isSupported } = await import('firebase/messaging');

      if (!(await isSupported())) {
        // Le cas d'iPhone hors écran d'accueil, principalement.
        return 'Votre navigateur ne gère pas encore les notifications web. '
          + 'Sur iPhone, ajoutez d’abord GARAH à votre écran d’accueil.';
      }

      const messagerie = getMessaging(initializeApp(firebase));
      const jeton = await getToken(messagerie, { vapidKey: cleVapid });
      if (!jeton) {
        return 'L’abonnement n’a pas abouti. Réessayez dans un instant.';
      }

      await this.declarer(jeton);
      this.abonne.set(true);
      return null;
    } catch (e) {
      // En développement, l'agent de service passe par le mandataire et
      // l'enregistrement échoue. Le dire, plutôt que de laisser croire à un
      // défaut de l'application.
      return 'Les notifications n’ont pas pu être activées sur cet appareil.';
    } finally {
      this.enCours.set(false);
    }
  }

  private async declarer(jeton: string): Promise<void> {
    await new Promise<void>((resoudre) => {
      this.http
        .put<void>('/api/notifications/appareils', { jeton, plateforme: 'WEB' })
        .subscribe({
          next: () => {
            this.jeton = jeton;
            resoudre();
          },
          // Réessayé au prochain clic : le serveur n'enverra rien d'ici là,
          // mais rien n'est cassé pour autant.
          error: () => resoudre(),
        });
    });
  }

  private async retirer(): Promise<void> {
    const jeton = this.jeton;
    this.jeton = null;
    this.abonne.set(false);
    if (!jeton) {
      return;
    }
    this.http.delete<void>(`/api/notifications/appareils/${jeton}`).subscribe({
      // Le serveur nettoie de lui-même : un envoi vers un jeton mort échoue,
      // et l'échec vaut désinscription.
      error: () => undefined,
    });
  }
}

function lirePermission(): NotificationPermission | null {
  // ⚠️ Le test doit être fait sans y toucher : lire `Notification.permission`
  //    sur un navigateur qui ne connaît pas l'API lève, et l'exception
  //    remonterait jusqu'au démarrage de l'application.
  return typeof Notification === 'undefined' ? null : Notification.permission;
}
