import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:garah_mobile/api/client_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Le contrat entre le mobile et l'API d'authentification.
///
/// ## 🎯 Ce que ces tests ferment
///
/// La connexion était **impossible** depuis le mobile : le bouton tournait
/// indéfiniment, sans message. Le code lisait une réponse qui n'a jamais
/// existé — cinq désaccords empilés avec ce que le serveur envoie réellement :
///
/// ```
/// le jeton était lu sous     jetonAcces      le serveur envoie  jeton
/// le compte était lu à la racine             il est dans        utilisateur
/// le cookie était cherché    rafraichissement   il s'appelle    garah_refresh_boutique
/// l'en-tête X-Garah-Client n'était jamais envoyé — 403 sur /rafraichir
/// et l'écran ne rattrapait que ErreurApi, donc rien ne s'affichait
/// ```
///
/// ## ⚠️ Pourquoi rien ne l'avait vu
///
/// Aucun test ne traversait cette couche, et l'application **compile**
/// parfaitement : lire une clé absente d'un JSON rend `null` en Dart, ce n'est
/// pas une erreur. Le désaccord ne se voit qu'à l'exécution, sur un vrai
/// serveur — c'est-à-dire jamais pendant le développement.
///
/// Les réponses ci-dessous sont **recopiées d'un appel réel** à l'API locale.
void main() {
  // Capturé le 09/09/2026 sur `POST /api/auth/connexion`, profil recette.
  const corpsReel = {
    'jeton': 'eyJhbGciOiJIUzI1NiJ9.charge-utile.signature',
    'typeJeton': 'Bearer',
    'expireDansSecondes': 900,
    'utilisateur': {
      'id': 1,
      'nom': 'Super Administrateur',
      'type': 'SUPER_ADMIN',
      'langue': 'fr',
      'urlPhoto': null,
    },
    'permissions': <String>[],
  };

  // ⚠️ Recopié tel quel, `Path` et `SameSite` compris : c'est la chaîne que le
  //    mobile doit savoir découper.
  const cookieReel =
      'garah_refresh_boutique=cRckrZx10N_rtYlMleKVgBH0VgPhsYefAobWKvlDIKY; '
      'Path=/api/auth; Max-Age=1209600; HttpOnly; SameSite=Lax';

  ClientApi clientQuiRend(Map<String, Object?> corps, {String? cookie}) {
    return ClientApi(
      transport: MockClient((requete) async {
        final entetes = <String, String>{'content-type': 'application/json'};
        if (cookie != null) entetes['set-cookie'] = cookie;
        return http.Response(jsonEncode(corps), 200, headers: entetes);
      }),
    );
  }

  group('la connexion', () {
    test('⚠️ lit le jeton sous le nom que le serveur emploie', () async {
      final api = clientQuiRend(corpsReel);
      final corps = await api.connecter('client@garah.cm', 'MotDePasse123');

      // Le champ s'appelle `jeton`. Lu sous `jetonAcces`, il valait null — et
      // TOUS les appels suivants partaient sans autorisation, en silence.
      expect(corps['jeton'], isNotNull);
      expect(ClientApi.champJeton, 'jeton');
    });

    test('⚠️ retient le cookie sous le nom que le serveur pose', () async {
      final api = clientQuiRend(corpsReel, cookie: cookieReel);
      await api.connecter('client@garah.cm', 'MotDePasse123');

      // Cherché sous `rafraichissement`, il n'était jamais trouvé : la session
      // mourait au premier rafraîchissement, sans rien dire.
      expect(api.jetonRafraichissement, isNotNull);
      expect(
        api.jetonRafraichissement,
        'cRckrZx10N_rtYlMleKVgBH0VgPhsYefAobWKvlDIKY',
      );
    });

    test(
      '⚠️ ne confond pas la session du back-office avec la sienne',
      () async {
        // Un même appareil ne porte pas les deux, mais le nom doit rester
        // distinct : c'est toute la séparation posée par D-33.
        final api = clientQuiRend(
          corpsReel,
          cookie: 'garah_refresh_admin=celui-du-back-office; Path=/api/auth',
        );
        await api.connecter('client@garah.cm', 'MotDePasse123');

        expect(api.jetonRafraichissement, isNull);
        expect(ClientApi.cookieSession, 'garah_refresh_boutique');
      },
    );

    test('le compte est IMBRIQUÉ, pas à la racine', () async {
      final api = clientQuiRend(corpsReel);
      final corps = await api.connecter('client@garah.cm', 'MotDePasse123');

      // C'est ce désaccord qui levait une TypeError — laquelle n'étant pas une
      // ErreurApi, l'écran ne la rattrapait pas et tournait pour toujours.
      expect(corps['utilisateurId'], isNull, reason: 'ce champ n’existe pas');
      expect((corps['utilisateur'] as Map)['id'], 1);
    });
  });

  group('l’en-tête exigé', () {
    test(
      '⚠️ le rafraîchissement porte X-Garah-Client, et le bon cookie',
      () async {
        // Sans cet en-tête, FiltreOrigineCsrf répond 403 sur /api/auth/rafraichir
        // — même avec un cookie parfaitement valide. Il n'était envoyé nulle
        // part : le rafraîchissement ne pouvait pas aboutir.
        final vues = <http.Request>[];
        var premierAppel = true;

        final api = ClientApi(
          transport: MockClient((requete) async {
            vues.add(requete);
            if (requete.url.path.endsWith('/api/auth/rafraichir')) {
              return http.Response(
                jsonEncode(corpsReel),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            // Le premier appel métier expire : c'est ce qui déclenche le
            // rafraîchissement.
            if (premierAppel) {
              premierAppel = false;
              return http.Response('', 401);
            }
            return http.Response(
              '{"contenu":[]}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        api.poserJeton('jeton-expire', rafraichissement: 'un-cookie-valide');

        await api.obtenir('/api/commandes');

        final rafraichissement = vues.firstWhere(
          (r) => r.url.path.endsWith('/api/auth/rafraichir'),
        );

        expect(
          rafraichissement.headers[ClientApi.enteteClient],
          isNotNull,
          reason: 'sans cet en-tête, le serveur répond 403',
        );
        expect(
          rafraichissement.headers['Cookie'],
          contains('garah_refresh_boutique='),
          reason: 'le cookie doit porter le nom que le serveur a posé',
        );
      },
    );
  });
}
