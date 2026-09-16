import '../api/client_api.dart';

/// Ce que l'API annonce sur son propre déploiement.
///
/// <h2>Pourquoi l'application ne le sait pas d'elle-même</h2>
///
/// L'identifiant Google, la disponibilité de WhatsApp, le préfixe des médias
/// changent selon le déploiement. Écrits dans l'application, chaque
/// changement imposerait une nouvelle version publiée — et un APK déjà
/// installé resterait faux jusqu'à ce que la personne le mette à jour.
///
/// L'API, elle, connaît sa configuration : elle l'annonce.
///
/// ⚠️ **Lu UNE fois, et partagé.** Chaque écran qui interrogerait
/// `/api/configuration` de son côté ajouterait un aller-retour sur une
/// connexion comptée — et pourrait afficher un bouton que l'écran voisin
/// n'affiche pas.
class ServiceConfiguration {
  ServiceConfiguration(this._api);

  final ClientApi _api;

  Map<String, dynamic>? _annonce;
  Future<void>? _enCours;

  /// L'identifiant du client **Web** Google, ou `null`.
  ///
  /// ⚠️ Web, et non Android : c'est lui qu'on passe en `serverClientId`, et
  /// lui qui figurera dans le `aud` du jeton. Le client Android ne sert qu'à
  /// prouver la signature de l'APK.
  String? get identifiantClientGoogle {
    final valeur = _annonce?['identifiantClientGoogle'];
    return valeur is String && valeur.isNotEmpty ? valeur : null;
  }

  /// « Continuer avec WhatsApp » peut-il être proposé ?
  bool get whatsappDisponible => _annonce?['whatsappDisponible'] == true;

  /// Les fournisseurs réellement configurés côté serveur.
  ///
  /// 🎯 L'écran n'affiche que ce qui est là. Un bouton dont la configuration
  /// n'est pas faite échouerait au clic, et la personne chercherait la panne
  /// chez elle — son compte, sa connexion — alors que le manque est chez nous.
  List<String> get fournisseurs {
    final brut = _annonce?['fournisseursSociaux'];
    return brut is List ? brut.map((f) => '$f').toList() : const [];
  }

  /// Interroge l'API, une seule fois, sans jamais lever.
  ///
  /// ⚠️ Deux appels simultanés partagent la même requête : sans `_enCours`,
  /// l'écran de connexion et celui du compte en déclencheraient deux au même
  /// instant.
  ///
  /// Un échec laisse simplement tous les boutons masqués : l'application doit
  /// rester utilisable avec le mot de passe, même si cet appel ne passe pas.
  Future<void> charger() {
    if (_annonce != null) return Future.value();
    return _enCours ??= _lire();
  }

  Future<void> _lire() async {
    try {
      final reponse = await _api.obtenir('/api/configuration');
      if (reponse is Map<String, dynamic>) {
        _annonce = reponse;
      }
    } catch (_) {
      // Volontairement avalé — voir la doc de `charger`.
    } finally {
      _enCours = null;
    }
  }
}
