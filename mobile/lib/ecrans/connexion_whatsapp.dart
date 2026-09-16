import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/client_api.dart';
import '../charte/theme.dart';
import '../services/services.dart';
import '../widgets/communs.dart';

/// « Continuer avec WhatsApp » — numéro, puis code.
///
/// <h2>⚠️ Ce n'est PAS une connexion WhatsApp</h2>
///
/// Meta n'expose aucune API de connexion. Le bouton porte ce nom parce que
/// c'est ce que la personne comprend, mais la mécanique est un **code à usage
/// unique** envoyé par message, que GARAH engendre et vérifie lui-même (D-51).
///
/// <h2>Deux étapes dans UN écran, et pas deux écrans</h2>
///
/// Le numéro reste visible pendant qu'on saisit le code. Sur deux écrans, on
/// ne peut plus vérifier qu'on l'a bien tapé — et c'est la première chose
/// qu'on veut regarder quand aucun message n'arrive.
class EcranConnexionWhatsApp extends StatefulWidget {
  const EcranConnexionWhatsApp({super.key});

  @override
  State<EcranConnexionWhatsApp> createState() => _EcranConnexionWhatsAppState();
}

class _EcranConnexionWhatsAppState extends State<EcranConnexionWhatsApp> {
  final _telephone = TextEditingController();
  final _code = TextEditingController();

  /// Le numéro tel que le SERVEUR l'a normalisé, masqué pour l'affichage.
  ///
  /// 🎯 C'est lui qu'on montre, pas la saisie : il prouve que le serveur a
  /// compris le même numéro que la personne croyait taper. « 699 00 07 77 »
  /// devient `+237 6•• •• •• 77`, et une erreur de pays se voit tout de suite.
  String? _numeroConfirme;

  bool _envoi = false;
  String? _echec;

  @override
  void dispose() {
    _telephone.dispose();
    _code.dispose();
    super.dispose();
  }

  bool get _etapeDuCode => _numeroConfirme != null;

  Future<void> _demanderLeCode() async {
    if (_envoi) return;
    setState(() {
      _envoi = true;
      _echec = null;
    });

    try {
      final masque = await Services.de(
        context,
      ).api.demanderUnCodeWhatsApp(_telephone.text.trim());

      if (!mounted) return;
      setState(() {
        _numeroConfirme = masque;
        _envoi = false;
      });
    } on ErreurApi catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _echec = e.message;
      });
    } catch (_) {
      // Le même filet qu'ailleurs : ce qui casse après la réponse ne lève pas
      // une ErreurApi, et le bouton tournerait indéfiniment sans message.
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _echec = 'L envoi a echoue. Reessayez dans un instant.';
      });
    }
  }

  Future<void> _verifierLeCode() async {
    if (_envoi) return;
    setState(() {
      _envoi = true;
      _echec = null;
    });

    final services = Services.de(context);
    final navigateur = Navigator.of(context);
    try {
      await services.session.connecterAvecWhatsApp(
        _telephone.text.trim(),
        _code.text.trim(),
      );
      if (mounted) navigateur.pop(true);
    } on ErreurApi catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _echec = e.message;
        // ⚠️ On VIDE le champ après un refus.
        //
        //    Le code est à usage unique et plafonné à cinq essais : laisser la
        //    saisie fautive invite à réappuyer sur « Valider » sans rien
        //    changer, et à brûler les tentatives une à une.
        _code.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _echec = 'La connexion a echoue. Reessayez dans un instant.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Continuer avec WhatsApp')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            _etapeDuCode
                ? 'Nous avons envoyé un code sur WhatsApp au $_numeroConfirme.'
                : 'Entrez votre numéro. Nous vous enverrons un code sur '
                      'WhatsApp — aucun mot de passe à retenir.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: context.texteAttenue,
            ),
          ),
          const SizedBox(height: 20),

          const Libelle('Numéro de téléphone'),
          const SizedBox(height: 6),
          TextField(
            controller: _telephone,
            // ⚠️ `phone` et non `number` : il faut le « + » et les espaces.
            keyboardType: TextInputType.phone,
            // Le numéro ne se modifie plus une fois le code parti : il a servi
            // à l'envoyer, et le changer sans redemander de code produirait un
            // refus que personne ne comprendrait.
            enabled: !_etapeDuCode,
            decoration: const InputDecoration(hintText: '+237 6 99 00 07 77'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          Text(
            'Cameroun (+237) ou Centrafrique (+236).',
            style: TextStyle(fontSize: 12, color: context.texteAttenue),
          ),

          if (_etapeDuCode) ...[
            const SizedBox(height: 18),
            const Libelle('Code reçu'),
            const SizedBox(height: 6),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              // À chasse fixe : un code se recopie chiffre par chiffre depuis
              // un autre écran, et une police proportionnelle rend un 1 et un
              // l indiscernables.
              style: const TextStyle(
                fontSize: 22,
                letterSpacing: 8,
                fontFamily: 'monospace',
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(counterText: ''),
              onChanged: (_) => setState(() {}),
            ),
            Text(
              'Le code expire au bout de cinq minutes.',
              style: TextStyle(fontSize: 12, color: context.texteAttenue),
            ),
          ],

          const SizedBox(height: 16),
          if (_echec != null) ...[
            Alerte(message: _echec!),
            const SizedBox(height: 12),
          ],

          FilledButton(
            onPressed: _envoi || !_saisieComplete
                ? null
                : (_etapeDuCode ? _verifierLeCode : _demanderLeCode),
            child: Text(
              _envoi
                  ? 'Un instant…'
                  : (_etapeDuCode ? 'Valider' : 'Recevoir le code'),
            ),
          ),

          if (_etapeDuCode) ...[
            const SizedBox(height: 10),
            TextButton(
              // ⚠️ Repartir du numéro, et non « renvoyer un code » : le serveur
              //    n'accepte que trois demandes par quart d'heure, et le
              //    premier réflexe quand rien n'arrive est de vérifier qu'on
              //    n'a pas tapé un chiffre de travers.
              onPressed: _envoi
                  ? null
                  : () => setState(() {
                      _numeroConfirme = null;
                      _code.clear();
                      _echec = null;
                    }),
              child: const Text('Corriger le numéro'),
            ),
          ],
        ],
      ),
    );
  }

  bool get _saisieComplete => _etapeDuCode
      ? _code.text.trim().length == 6
      : _telephone.text.trim().length >= 8;
}
