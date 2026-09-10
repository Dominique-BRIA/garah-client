import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../api/client_api.dart';

/// Le caractère qui termine une trame STOMP : l'octet NUL.
///
/// ⚠️ Écrit en échappement, jamais en clair. Un octet nul posé tel quel dans
///    un fichier source se confond à l'œil avec un espace et survit mal aux
///    outils de format — et le jour où il devient un vrai espace, plus AUCUNE
///    trame n'est reconnue, sans le moindre message d'erreur.
const String _fin = '\u0000';

/// Les attentes successives avant de retenter.
const List<Duration> _reprises = [
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 5),
  Duration(seconds: 10),
  Duration(seconds: 30),
];

/// Le temps réel : STOMP sur WebSocket, écrit à la main.
///
/// ## 🎯 Ce que ça remplace
///
/// Un message envoyé n'apparaissait chez l'autre qu'au rechargement de
/// l'écran. Le client tirait sur la liste pour savoir si le conseiller avait
/// répondu — et recommençait toutes les vingt secondes.
///
/// ## ⚠️ Aucun paquet
///
/// Le protocole tient en quarante lignes : une commande, des en-têtes, une
/// ligne vide, un corps, un octet nul. `dart:io` fournit déjà le WebSocket.
/// C'est la règle du `pubspec` : tout ce qui peut s'écrire à la main s'écrit
/// à la main — chaque paquet ajouté est du téléchargement à chaque passage de
/// CI et du poids dans l'APK.
///
/// ## ⚠️ Ce client ne fait QUE recevoir
///
/// On écrit toujours en HTTP, qui sait dire « refusé » et pourquoi. Un POST
/// rejeté affiche un message ; une trame STOMP perdue ne dit rien à personne.
///
/// ## ⚠️ Le jeton voyage dans la trame CONNECT
///
/// `dart:io` accepterait un en-tête à la poignée de main, mais le serveur
/// attend le jeton dans le CONNECT — c'est la seule forme que le navigateur
/// sait produire, et les trois applications parlent donc la même.
class ServiceTempsReel {
  ServiceTempsReel(this._api);

  final ClientApi _api;

  WebSocket? _prise;
  StreamSubscription<dynamic>? _ecoute;
  bool _connecte = false;
  int _compteur = 0;
  int _essais = 0;
  Timer? _minuterie;
  bool _ferme = false;

  final Map<String, _Abonnement> _abonnes = {};

  /// Écoute une destination. Rend la fonction qui coupe l'écoute.
  ///
  /// La connexion s'ouvre au PREMIER abonnement et se ferme au dernier : un
  /// écran qui n'écoute rien ne tient pas de prise ouverte — sur un téléphone,
  /// une prise ouverte réveille la radio et vide la batterie.
  void Function() abonner(
    String destination,
    void Function(Map<String, dynamic>) surMessage,
  ) {
    final id = 'sub-${_compteur++}';
    _abonnes[id] = _Abonnement(destination, surMessage);

    if (_connecte) {
      _souscrire(id, destination);
    } else {
      _ouvrir();
    }

    return () {
      _abonnes.remove(id);
      if (_connecte) {
        _envoyer('UNSUBSCRIBE', {'id': id});
      }
      if (_abonnes.isEmpty) {
        _fermer();
      }
    };
  }

  /// Coupe tout. Appelé quand l'application s'arrête ou que la session tombe.
  void arreter() {
    _abonnes.clear();
    _fermer();
  }

  // ---------------------------------------------------------------------------
  // La prise
  // ---------------------------------------------------------------------------

  Future<void> _ouvrir() async {
    if (_prise != null || _abonnes.isEmpty) {
      return;
    }

    // ⚠️ Sans session, on n'ouvre RIEN. Le serveur accepterait la connexion —
    //    il ne refuse pas brutalement, pour ne pas faire boucler le client —
    //    mais aucune file personnelle ne lui serait adressée. Une prise
    //    ouverte qui ne recevra jamais rien est pire qu'aucune prise : elle a
    //    l'air de marcher.
    final jeton = _api.jetonAcces;
    if (jeton == null || jeton.isEmpty) {
      return;
    }

    _ferme = false;
    final adresse = '${urlApi.replaceFirst(RegExp(r'^http'), 'ws')}/ws';

    WebSocket prise;
    try {
      prise = await WebSocket.connect(adresse);
    } catch (_) {
      // Réseau absent, nom d'hôte filtré, serveur éteint : on retente.
      _reprendre();
      return;
    }

    // L'écran a pu être quitté pendant la poignée de main.
    if (_abonnes.isEmpty || _ferme) {
      await prise.close();
      return;
    }

    _prise = prise;
    _ecoute = prise.listen(
      (donnees) => _recevoir(donnees.toString()),
      onDone: _surCoupure,
      onError: (_) => _surCoupure(),
      cancelOnError: true,
    );

    _envoyer('CONNECT', {
      'accept-version': '1.2',
      // Ni l'un ni l'autre n'envoie de battement : le courtier en mémoire de
      // Spring n'en émet pas sans ordonnanceur, et un client qui en attendrait
      // couperait à tort.
      'heart-beat': '0,0',
      'Authorization': 'Bearer $jeton',
    });
  }

  void _surCoupure() {
    _connecte = false;
    _ecoute = null;
    _prise = null;
    // Une coupure n'est pas une erreur : le réseau mobile tombe à chaque
    // tunnel. On retente tant qu'un écran écoute.
    _reprendre();
  }

  void _fermer() {
    _ferme = true;
    _minuterie?.cancel();
    _minuterie = null;
    _connecte = false;

    final ecoute = _ecoute;
    _ecoute = null;
    final prise = _prise;
    _prise = null;

    // On annule l'écoute AVANT de fermer : sinon `onDone` déclencherait une
    // reprise, et la prise se rouvrirait toute seule.
    ecoute?.cancel();
    prise?.close();
  }

  /// Retente, de plus en plus espacé.
  ///
  /// ⚠️ Un intervalle FIXE est ce qu'il ne faut pas faire. Quand le serveur
  ///    redémarre, tous les téléphones ouverts retentent en même temps et le
  ///    noient au moment où il est le plus fragile.
  void _reprendre() {
    if (_abonnes.isEmpty || _minuterie != null || _ferme) {
      return;
    }
    final attente = _reprises[_essais.clamp(0, _reprises.length - 1)];
    _essais++;
    _minuterie = Timer(attente, () {
      _minuterie = null;
      _ouvrir();
    });
  }

  // ---------------------------------------------------------------------------
  // Le protocole
  // ---------------------------------------------------------------------------

  void _envoyer(
    String commande,
    Map<String, String> entetes, [
    String corps = '',
  ]) {
    final prise = _prise;
    if (prise == null) {
      return;
    }
    final lignes = entetes.entries.map((e) => '${e.key}:${e.value}').join('\n');
    try {
      prise.add('$commande\n$lignes\n\n$corps$_fin');
    } catch (_) {
      // Prise fermée entre-temps : `onDone` programmera la reprise.
    }
  }

  void _souscrire(String id, String destination) {
    _envoyer('SUBSCRIBE', {'id': id, 'destination': destination});
  }

  void _recevoir(String donnees) {
    // Une trame WebSocket peut en contenir plusieurs.
    for (final brute in donnees.split(_fin)) {
      final trame = brute.replaceFirst(RegExp(r'^\n+'), '');
      if (trame.isEmpty) {
        continue;
      }

      final separation = trame.indexOf('\n\n');
      final tete = separation == -1 ? trame : trame.substring(0, separation);
      final corps = separation == -1 ? '' : trame.substring(separation + 2);

      final lignes = tete.split('\n');
      final commande = lignes.first;

      if (commande == 'CONNECTED') {
        _connecte = true;
        _essais = 0;
        // On reprend TOUS les abonnements : après une coupure le serveur ne se
        // souvient de rien. Sans cela l'écran resterait muet en paraissant
        // connecté.
        _abonnes.forEach(_souscrireEntree);
        continue;
      }

      if (commande != 'MESSAGE') {
        // ERROR, RECEIPT : rien à faire. Une ERROR ferme la prise côté
        // serveur, et `onDone` programmera la reprise.
        continue;
      }

      String? souscription;
      for (final ligne in lignes.skip(1)) {
        final i = ligne.indexOf(':');
        if (i > 0 && ligne.substring(0, i) == 'subscription') {
          souscription = ligne.substring(i + 1);
          break;
        }
      }

      final abonne = _abonnes[souscription];
      if (abonne == null) {
        continue;
      }

      try {
        final charge = jsonDecode(corps);
        if (charge is Map<String, dynamic>) {
          abonne.surMessage(charge);
        }
      } catch (_) {
        // ⚠️ Un corps illisible ne doit pas tuer la boucle : les trames
        //    suivantes, elles, sont peut-être bonnes.
      }
    }
  }

  void _souscrireEntree(String id, _Abonnement a) =>
      _souscrire(id, a.destination);
}

class _Abonnement {
  const _Abonnement(this.destination, this.surMessage);

  final String destination;
  final void Function(Map<String, dynamic>) surMessage;
}
