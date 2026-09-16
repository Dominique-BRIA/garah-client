import 'package:google_sign_in/google_sign_in.dart';

import '../api/client_api.dart';

/// « Continuer avec Google » — la partie qui parle à Google.
///
/// ⚠️ **Ce service ne connecte personne.** Il obtient un *jeton d'identité*
/// signé par Google, et rien d'autre. C'est le serveur qui vérifie ce jeton et
/// qui décide s'il ouvre une session (D-51). Un client qui déciderait lui-même
/// qu'il est connecté n'aurait aucune valeur : il suffirait de modifier
/// l'application pour entrer.
///
/// ## Pourquoi un paquet, alors que la liste est volontairement courte
///
/// Le `pubspec` dit que tout ce qui peut s'écrire à la main s'écrit à la main.
/// Celui-ci est une exception assumée : sur Android, obtenir un jeton
/// d'identité passe par **Credential Manager** et les services Google Play,
/// c'est-à-dire par du code natif. La seule alternative serait d'ouvrir un
/// navigateur sur un flux OAuth complet — plus de code, moins sûr, et une
/// expérience nettement pire que la feuille native qui liste les comptes déjà
/// présents sur le téléphone.
class ServiceGoogle {
  ServiceGoogle(this._api);

  final ClientApi _api;

  /// L'identifiant du client **Web**, annoncé par l'API.
  ///
  /// ⚠️ **Web, et non Android — c'est le piège de cette intégration.**
  ///
  /// ```text
  /// client Android   prouve que l APK est bien signe par nous
  ///                  (package + empreinte SHA-1)
  /// client Web       c est SON identifiant qu on passe ici, et c est
  ///                  lui qui figurera dans le `aud` du jeton
  /// ```
  ///
  /// Les deux doivent exister, et **dans le même projet Google Cloud que
  /// l'application Android** — celui de `google-services.json`. Un client web
  /// créé dans un autre projet produit un échec que rien n'explique.
  String? _identifiantServeur;

  bool _pret = false;

  /// Vrai quand le bouton peut être proposé.
  ///
  /// Faux si l'API n'annonce aucun identifiant, ou si la plateforme ne sait
  /// pas authentifier (le web passe par un autre mécanisme). On n'affiche
  /// alors pas le bouton du tout : **dire ce qui manque avant le clic**, plutôt
  /// que de laisser quelqu'un appuyer sur une porte murée.
  bool get disponible =>
      _pret &&
      _identifiantServeur != null &&
      _identifiantServeur!.isNotEmpty &&
      GoogleSignIn.instance.supportsAuthenticate();

  /// Demande sa configuration à l'API, puis initialise le SDK.
  ///
  /// ⚠️ **Appelée au moment d'afficher l'écran de connexion, jamais au
  /// démarrage.** L'application doit s'ouvrir et montrer le catalogue même si
  /// l'API est injoignable ; faire dépendre le lancement d'un appel réseau
  /// rendrait la boutique inutilisable pour une fonctionnalité annexe.
  ///
  /// Ne lève jamais : un échec laisse simplement [disponible] à faux.
  Future<void> preparer() async {
    if (_pret) return;

    try {
      final config = await _api.obtenir('/api/configuration');
      final identifiant =
          (config as Map<String, dynamic>)['identifiantClientGoogle'];

      // ⚠️ La clé est toujours présente côté serveur, et une chaîne VIDE
      //    signifie « ne propose pas ce bouton ». On traite donc le vide
      //    exactement comme l'absence — sans quoi on initialiserait le SDK
      //    avec une chaîne vide et l'échec surviendrait au clic.
      if (identifiant is! String || identifiant.isEmpty) {
        _pret = true;
        return;
      }

      _identifiantServeur = identifiant;
      await GoogleSignIn.instance.initialize(serverClientId: identifiant);
      _pret = true;
    } catch (_) {
      // Volontairement avalé. L'écran de connexion par mot de passe doit
      // rester utilisable même si cette préparation échoue.
      _pret = true;
    }
  }

  /// Ouvre la feuille Google et renvoie le jeton d'identité.
  ///
  /// Renvoie `null` si la personne **annule** — ce n'est pas une erreur, et
  /// afficher un message rouge parce que quelqu'un a changé d'avis serait
  /// désagréable pour rien.
  ///
  /// Lève une [ErreurApi] pour tout le reste, afin que l'écran de connexion
  /// l'affiche comme n'importe quel autre échec, sans code particulier.
  Future<String?> obtenirLeJeton() async {
    try {
      final compte = await GoogleSignIn.instance.authenticate();
      final jeton = compte.authentication.idToken;

      if (jeton == null || jeton.isEmpty) {
        // Arrive quand `serverClientId` est absent, faux, ou déclaré dans un
        // AUTRE projet que l'application Android. Le message le dit, parce que
        // c'est l'erreur de configuration la plus probable — et la seule que
        // l'utilisateur ne peut pas résoudre lui-même.
        throw ErreurApi(
          0,
          'Google n\'a pas fourni de jeton. Configuration incomplète.',
        );
      }

      return jeton;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      throw ErreurApi(0, 'Connexion Google impossible. Réessayez.');
    }
  }

  /// Oublie le compte choisi sur cet appareil.
  ///
  /// ⚠️ À appeler à la déconnexion. Sans cela, Google reproposerait
  /// silencieusement le même compte, et **changer de compte deviendrait
  /// impossible** depuis l'application — un défaut que l'utilisateur vit comme
  /// « je ne peux pas me déconnecter ».
  Future<void> oublier() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Sans effet sur la déconnexion GARAH, qui a déjà eu lieu.
    }
  }
}
