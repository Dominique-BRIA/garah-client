import 'dart:convert';

import 'package:http/http.dart' as http;

/// L'adresse de l'API.
///
/// ⚠️ Elle se passe au build : `--dart-define=GARAH_API=https://…`. L'écrire
///    en dur obligerait à recompiler pour changer d'environnement, et surtout
///    à modifier le code pour tester contre un serveur local — ce que
///    personne ne fait proprement dans l'urgence.
const String urlApi = String.fromEnvironment(
  'GARAH_API',
  defaultValue:
      'https://garah-api-anfeapebbth7h7an.francecentral-01.azurewebsites.net',
);

/// Une réponse d'erreur du serveur, telle qu'on peut la montrer.
class ErreurApi implements Exception {
  ErreurApi(this.statut, this.message);

  final int statut;
  final String message;

  /// Sans réseau du tout : ni serveur joint, ni réponse.
  bool get estReseau => statut == 0;

  @override
  String toString() => message;
}

/// Le client HTTP de l'application.
///
/// ## 🎯 Un seul endroit qui sait parler au serveur
///
/// Le jeton, le rafraîchissement, le décodage et la traduction des erreurs
/// vivent ici. Répartis dans les écrans, ils divergeraient : l'un
/// rafraîchirait, l'autre déconnecterait, un troisième afficherait un code
/// HTTP brut à l'utilisateur.
///
/// ## ⚠️ Le rafraîchissement ne se tente qu'UNE fois
///
/// Un 401 sur l'appel de rafraîchissement lui-même signifie que la session est
/// morte. Réessayer donnerait une boucle infinie qui vide la batterie et le
/// forfait sans jamais aboutir.
class ClientApi {
  ClientApi({http.Client? transport}) : _http = transport ?? http.Client();

  /// Le champ qui porte le jeton d'acces dans la reponse de connexion.
  ///
  /// ⚠️ Il etait lu sous le nom `jetonAcces`. Le serveur envoie `jeton`, et
  ///    l'a toujours envoye. Le mobile lisait donc `null`, tous les appels
  ///    suivants partaient sans autorisation, et rien ne le disait.
  static const champJeton = 'jeton';

  /// Le cookie de session, cote boutique.
  ///
  /// ⚠️ Il etait cherche sous le nom `rafraichissement`, que le serveur n'a
  ///    JAMAIS employe. Le cookie n'etait donc jamais capture, et la session
  ///    mourait au premier rafraichissement.
  ///
  /// ⚠️ Le back-office range la sienne sous `garah_refresh_admin` (D-33). Le
  ///    mobile est du cote boutique : il ne doit pas lire celui-la.
  static const cookieSession = 'garah_refresh_boutique';

  /// L'en-tete exige par le serveur sur `/api/auth/rafraichir` et
  /// `/api/auth/deconnexion` (FiltreOrigineCsrf).
  ///
  /// ⚠️ Il n'etait envoye nulle part : les deux routes repondaient 403, et le
  ///    rafraichissement echouait meme quand tout le reste etait juste.
  ///
  /// Une application native n'est pas concernee par le CSRF, mais la route ne
  /// distingue pas ses appelants : elle l'exige de tout le monde.
  static const enteteClient = 'X-Garah-Client';

  final http.Client _http;

  String? _jeton;

  /// Le cookie de rafraîchissement, renvoyé par la connexion.
  ///
  /// Sur le web il est posé par le navigateur ; ici il faut le tenir soi-même.
  String? _rafraichissement;

  /// Appelé quand la session est définitivement perdue.
  void Function()? surSessionPerdue;

  /// Le jeton d acces courant.
  ///
  /// Expose pour le temps reel : le client STOMP le pose dans la trame
  /// CONNECT, hors de toute requete HTTP.
  String? get jetonAcces => _jeton;

  void poserJeton(String? jeton, {String? rafraichissement}) {
    _jeton = jeton;
    if (rafraichissement != null) {
      _rafraichissement = rafraichissement;
    }
  }

  void oublier() {
    _jeton = null;
    _rafraichissement = null;
  }

  bool get aUnJeton => _jeton != null;

  // ---------------------------------------------------------------------------

  Future<dynamic> obtenir(String chemin) => _appeler('GET', chemin);

  Future<dynamic> poster(String chemin, [Object? corps]) =>
      _appeler('POST', chemin, corps);

  Future<dynamic> mettre(String chemin, [Object? corps]) =>
      _appeler('PUT', chemin, corps);

  Future<dynamic> supprimer(String chemin) => _appeler('DELETE', chemin);

  // ---------------------------------------------------------------------------

  Future<dynamic> _appeler(
    String methode,
    String chemin, [
    Object? corps,
    bool dejaRafraichi = false,
  ]) async {
    final uri = Uri.parse('$urlApi$chemin');
    final entetes = <String, String>{
      'Accept': 'application/json',
      if (corps != null) 'Content-Type': 'application/json',
      if (_jeton != null) 'Authorization': 'Bearer $_jeton',
    };

    http.Response reponse;
    try {
      reponse = await _envoyer(methode, uri, entetes, corps);
    } catch (_) {
      // ⚠️ Le cas le plus fréquent sur le terrain, et ce n'est PAS une panne
      //    du serveur : une connexion coupée en pleine rue. Le dire comme tel
      //    évite de faire croire que la boutique est fermée.
      throw ErreurApi(0, 'Pas de connexion. Réessayez dans un instant.');
    }

    if (reponse.statusCode == 401 &&
        !dejaRafraichi &&
        _rafraichissement != null) {
      if (await _rafraichir()) {
        return _appeler(methode, chemin, corps, true);
      }
      surSessionPerdue?.call();
    }

    if (reponse.statusCode >= 200 && reponse.statusCode < 300) {
      if (reponse.body.isEmpty) {
        return null;
      }
      return jsonDecode(utf8.decode(reponse.bodyBytes));
    }

    throw ErreurApi(reponse.statusCode, _messageDe(reponse));
  }

  Future<http.Response> _envoyer(
    String methode,
    Uri uri,
    Map<String, String> entetes,
    Object? corps,
  ) {
    final charge = corps == null ? null : jsonEncode(corps);
    switch (methode) {
      case 'POST':
        return _http.post(uri, headers: entetes, body: charge);
      case 'PUT':
        return _http.put(uri, headers: entetes, body: charge);
      case 'DELETE':
        return _http.delete(uri, headers: entetes);
      default:
        return _http.get(uri, headers: entetes);
    }
  }

  Future<bool> _rafraichir() async {
    try {
      final reponse = await _http.post(
        Uri.parse('$urlApi/api/auth/rafraichir'),
        headers: {
          'Accept': 'application/json',
          enteteClient: 'mobile',
          'Cookie': '$cookieSession=$_rafraichissement',
        },
      );
      if (reponse.statusCode != 200) {
        return false;
      }
      final corps = jsonDecode(utf8.decode(reponse.bodyBytes));
      _jeton = corps[champJeton] as String?;
      _lireLeCookie(reponse);
      return _jeton != null;
    } catch (_) {
      return false;
    }
  }

  /// Récupère le cookie de rafraîchissement d'une réponse de connexion.
  ///
  /// ⚠️ `http` ne tient aucun magasin de cookies : sans cette lecture, la
  ///    session expire au bout de quelques minutes et l'utilisateur est
  ///    déconnecté en plein achat, sans comprendre pourquoi.
  void _lireLeCookie(http.Response reponse) {
    final brut = reponse.headers['set-cookie'];
    if (brut == null) {
      return;
    }
    for (final morceau in brut.split(',')) {
      final paire = morceau.split(';').first.trim();
      final egal = paire.indexOf('=');
      if (egal > 0 && paire.substring(0, egal) == cookieSession) {
        _rafraichissement = paire.substring(egal + 1);
        return;
      }
    }
  }

  /// La connexion, à part : c'est le seul appel qui lit un cookie.
  Future<Map<String, dynamic>> connecter(
    String email,
    String motDePasse,
  ) async {
    http.Response reponse;
    try {
      reponse = await _http.post(
        Uri.parse('$urlApi/api/auth/connexion'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email, 'motDePasse': motDePasse}),
      );
    } catch (_) {
      throw ErreurApi(0, 'Pas de connexion. Réessayez dans un instant.');
    }

    if (reponse.statusCode != 200) {
      throw ErreurApi(
        reponse.statusCode,
        reponse.statusCode == 401
            // Un message VOLONTAIREMENT identique pour un e-mail inconnu et un
            // mot de passe faux : distinguer les deux dirait à un inconnu
            // quelles adresses ont un compte chez nous.
            ? 'Adresse ou mot de passe incorrect.'
            : _messageDe(reponse),
      );
    }

    final corps =
        jsonDecode(utf8.decode(reponse.bodyBytes)) as Map<String, dynamic>;
    _jeton = corps[champJeton] as String?;
    _lireLeCookie(reponse);
    return corps;
  }

  String? get jetonRafraichissement => _rafraichissement;

  /// Ce que le serveur a refusé, dit CHAMP PAR CHAMP.
  ///
  /// Sur une erreur de validation, il renvoie **deux** choses : un `message`
  /// générique — « Certains champs sont invalides. » — et un objet `champs` qui
  /// dit **lequel** et **pourquoi**.
  ///
  /// ⚠️ Ne lire que `message`, c'est ne montrer que la moins utile des deux.
  ///    Sur l'inscription, cela rend la création de compte **impossible en
  ///    pratique** : on voit « Certains champs sont invalides », on corrige au
  ///    hasard, et on renonce. Le défaut a été trouvé sur le web, où il
  ///    empêchait réellement de s'inscrire ; il était identique ici.
  ///
  /// ⚠️ Les messages du serveur sont repris TELS QUELS. Les réécrire les
  ///    ferait diverger au premier changement de règle — le jour où le minimum
  ///    passe de six à huit, le serveur le dira et l'application continuerait
  ///    d'annoncer six.
  static String _messageDe(http.Response reponse) {
    try {
      final corps = jsonDecode(utf8.decode(reponse.bodyBytes));
      if (corps is! Map) {
        return 'Une erreur est survenue. Réessayez.';
      }

      final champs = corps['champs'];
      if (champs is Map && champs.isNotEmpty) {
        final detail = champs.values
            .whereType<String>()
            .where((v) => v.isNotEmpty)
            .toList();
        if (detail.isNotEmpty) {
          return detail.join(' ');
        }
      }

      // Le serveur sait pourquoi il refuse — stock insuffisant, quantité trop
      // grande, offre expirée. Son message est plus juste que celui qu'on
      // inventerait ici.
      if (corps['message'] is String) {
        return corps['message'] as String;
      }
    } catch (_) {
      // Corps illisible : on retombe sur la phrase générique.
    }
    return 'Une erreur est survenue. Réessayez.';
  }
}
