import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../charte/jetons.dart';
import '../charte/theme.dart';
import '../services/services.dart';
import '../widgets/communs.dart';
import 'inscription.dart';

/// La connexion.
///
/// ## ⚠️ Le message d'échec ne distingue PAS les deux causes
///
/// « Adresse ou mot de passe incorrect », jamais « ce compte n'existe pas » :
/// séparer les deux dirait à un inconnu quelles adresses ont un compte chez
/// nous, ce qui suffit à monter une liste.
///
/// ## Le panier fusionne ici
///
/// C'est le service de session qui s'en charge, et son échec ne fait **pas**
/// échouer la connexion : on vient de saisir un mot de passe, renvoyer sur cet
/// écran parce qu'un panier n'a pas fusionné ferait recommencer pour rien.
class EcranConnexion extends StatefulWidget {
  const EcranConnexion({super.key});

  @override
  State<EcranConnexion> createState() => _EcranConnexionState();
}

class _EcranConnexionState extends State<EcranConnexion> {
  final _email = TextEditingController();
  final _motDePasse = TextEditingController();

  bool _masque = true;
  bool _envoi = false;
  String? _echec;

  @override
  void dispose() {
    _email.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  /// Ce qui manque encore, en une phrase.
  ///
  /// 🎯 Dire ce qui manque **avant** le clic. Un bouton grisé sans raison fait
  ///    chercher la panne ailleurs — souvent dans la connexion réseau.
  String? get _manque {
    if (!_email.text.contains('@')) return 'Entrez votre adresse e-mail.';
    if (_motDePasse.text.isEmpty) return 'Entrez votre mot de passe.';
    return null;
  }

  Future<void> _connecter() async {
    if (_manque != null || _envoi) return;
    setState(() {
      _envoi = true;
      _echec = null;
    });

    final session = Services.de(context).session;
    final navigateur = Navigator.of(context);
    try {
      await session.connecter(_email.text.trim(), _motDePasse.text);
      if (mounted) navigateur.pop();
    } on ErreurApi catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _echec = e.message;
      });
    } catch (_) {
      // 🎯 LE FILET. Sans lui, le bouton tourne pour toujours.
      //
      //    Ne rattraper que `ErreurApi` semble propre : c'est le type que la
      //    couche reseau leve. Mais tout ce qui casse APRES la reponse —
      //    un champ absent, un cast qui echoue, une preference illisible —
      //    leve autre chose. L'exception s'echappait alors de `_connecter`,
      //    `_envoi` restait a `true`, et l'ecran tournait indefiniment SANS
      //    message. C'est exactement ce qui se passait : le compte etait lu
      //    a la racine de la reponse au lieu de `utilisateur`, et le cast
      //    d'un `null` levait une TypeError.
      //
      // ⚠️ Le message reste volontairement vague : on ne montre pas le detail
      //    technique d'une panne qu'on n'a pas prevue. Ce qui compte, c'est
      //    que l'ecran REDEVIENNE utilisable.
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
      appBar: AppBar(title: const Text('Se connecter')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Votre panier vous suit : ce que vous avez mis de côté sera '
            'retrouvé après la connexion.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: context.texteAttenue,
            ),
          ),
          const SizedBox(height: 20),
          const Libelle('Adresse e-mail'),
          const SizedBox(height: 6),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            // ⚠️ Sans cette ligne, le clavier met une majuscule au premier
            //    caractère et l'adresse part fausse — un classique sur
            //    Android, et l'utilisateur ne voit pas d'où vient le refus.
            textCapitalization: TextCapitalization.none,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'vous@exemple.com'),
          ),
          const SizedBox(height: 16),
          const Libelle('Mot de passe'),
          const SizedBox(height: 6),
          TextField(
            controller: _motDePasse,
            obscureText: _masque,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _connecter(),
            decoration: InputDecoration(
              suffixIcon: IconButton(
                // Le montrer est une AIDE, pas une faille : au clavier
                // tactile, un mot de passe long se tape faux une fois sur
                // deux, et on renonce plutôt que de recommencer à l'aveugle.
                onPressed: () => setState(() => _masque = !_masque),
                tooltip: _masque ? 'Afficher' : 'Masquer',
                icon: Icon(
                  _masque
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_manque != null &&
              (_email.text.isNotEmpty || _motDePasse.text.isNotEmpty))
            Text(
              _manque!,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFFF59E0B)),
            ),
          if (_echec != null) ...[
            Alerte(message: _echec!),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 4),
          FilledButton(
            onPressed: _manque == null && !_envoi ? _connecter : null,
            child: Text(_envoi ? 'Connexion…' : 'Se connecter'),
          ),

          const SizedBox(height: 20),
          // 🎯 Sans ce lien, l'écran d'inscription n'existait pas : rien n'y
          //    menait, et un client sans compte n'avait aucun moyen d'en
          //    créer un depuis le téléphone.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Pas encore de compte ? ',
                style: TextStyle(fontSize: 13.5, color: context.texteAttenue),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EcranInscription()),
                ),
                child: const Text(
                  'Créer un compte',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Jetons.primaire,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
