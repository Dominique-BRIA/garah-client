import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../api/client_api.dart';
import 'session.dart';

/// Ce qu'un message pousse l'application à ouvrir.
///
/// Le serveur envoie un `type` et un identifiant ; l'application décide de
/// l'écran. L'inverse — une route toute faite dans le message — figerait la
/// navigation du mobile dans le backend, et changer un chemin casserait les
/// notifications déjà parties.
typedef SurNotification = void Function(String type, String? id);

/// Les notifications poussées.
///
/// ## 🎯 Trois moments, et trois seulement
///
/// - **la marchandise est arrivée** — c'est là qu'on donne le code de retrait ;
/// - **un conseiller a répondu** à une discussion ;
/// - **une proposition de prix** a été faite ou acceptée.
///
/// Le reste — commande payée, colis parti — se voit déjà dans l'application.
/// Une notification pour chacun apprend à les ignorer toutes, et le jour où la
/// marchandise arrive vraiment, plus personne ne regarde.
///
/// ## ⚠️ Le jeton est lié à un COMPTE, pas à un téléphone
///
/// Sur un appareil partagé, garder le jeton après une déconnexion enverrait au
/// suivant les notifications du précédent — y compris « votre marchandise vous
/// attend », qui désigne un colis qui n'est pas le sien. Il se déclare à la
/// connexion et se retire à la déconnexion.
///
/// ## ⚠️ Rien ici ne doit empêcher l'application de démarrer
///
/// Firebase peut être injoignable, la permission refusée, le service Google
/// absent du téléphone — c'est courant sur les appareils vendus hors des
/// circuits officiels. Chaque échec est avalé : une boutique qui ne s'ouvre
/// pas parce qu'une notification n'a pas pu s'abonner serait absurde.
class ServiceNotifications {
  ServiceNotifications(this._api, this._session);

  final ClientApi _api;
  final ServiceSession _session;

  /// Le jeton déclaré au serveur, pour savoir lequel retirer.
  String? _jetonDeclare;

  /// Appelé quand on touche une notification.
  SurNotification? surOuverture;

  bool _demarre = false;

  Future<void> demarrer() async {
    if (_demarre) return;
    _demarre = true;

    try {
      await Firebase.initializeApp();
    } catch (e) {
      // Services Google absents, configuration illisible : l'application vit
      // très bien sans notifications.
      debugPrint('Notifications indisponibles : $e');
      return;
    }

    try {
      final messagerie = FirebaseMessaging.instance;

      // ⚠️ On DEMANDE la permission, on ne la suppose pas. Sur Android 13 et
      //    au-delà, comme sur iOS, un envoi sans autorisation part et
      //    n'arrive nulle part — sans erreur.
      final reglage = await messagerie.requestPermission();
      if (reglage.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      // Le message qui a OUVERT l'application depuis un état fermé. Il ne
      // repasse jamais par `onMessageOpenedApp` : sans cette lecture, toucher
      // une notification sur un téléphone éteint ouvre l'accueil, et on
      // cherche soi-même ce qu'on venait voir.
      final initial = await messagerie.getInitialMessage();
      if (initial != null) _router(initial);

      FirebaseMessaging.onMessageOpenedApp.listen(_router);

      // Le jeton change tout seul — réinstallation, restauration, purge du
      // cache. S'abonner une fois au démarrage laisserait le serveur écrire
      // vers une adresse morte.
      messagerie.onTokenRefresh.listen(_declarer);

      final jeton = await messagerie.getToken();
      if (jeton != null) await _declarer(jeton);

      // La session pilote l'abonnement : le jeton appartient au compte
      // connecté, pas au téléphone.
      _session.addListener(_suivreLaSession);
    } catch (e) {
      debugPrint('Notifications non abonnées : $e');
    }
  }

  void _suivreLaSession() {
    if (_session.connecte) {
      FirebaseMessaging.instance
          .getToken()
          .then((j) {
            if (j != null) _declarer(j);
          })
          .catchError((_) => null);
    } else {
      _retirer();
    }
  }

  Future<void> _declarer(String jeton) async {
    if (!_session.connecte) {
      // Sans compte, il n'y a personne à qui adresser une notification. On
      // garde le jeton pour le déclarer à la connexion.
      _jetonDeclare = jeton;
      return;
    }
    try {
      await _api.mettre('/api/notifications/appareils', {
        'jeton': jeton,
        'plateforme': 'ANDROID',
      });
      _jetonDeclare = jeton;
    } catch (e) {
      // Réessayé au prochain démarrage : le serveur n'enverra simplement rien
      // d'ici là.
      debugPrint('Jeton non déclaré : $e');
    }
  }

  Future<void> _retirer() async {
    final jeton = _jetonDeclare;
    if (jeton == null) return;
    try {
      await _api.supprimer('/api/notifications/appareils/$jeton');
    } catch (_) {
      // Le serveur nettoiera de lui-même : un envoi vers un jeton mort
      // échoue, et l'échec vaut désinscription.
    }
    _jetonDeclare = null;
  }

  void _router(RemoteMessage message) {
    final type = message.data['type'];
    if (type is! String) return;
    surOuverture?.call(type, message.data['id']?.toString());
  }

  void arreter() {
    _session.removeListener(_suivreLaSession);
  }
}
