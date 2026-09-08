import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../charte/jetons.dart';
import '../charte/theme.dart';
import '../services/services.dart';
import '../widgets/communs.dart';

/// ⚠️ SIX, et c'est le serveur qui décide.
///
/// La valeur de référence est `ServiceInscription.LONGUEUR_MOT_DE_PASSE_MIN`,
/// côté serveur. Elle est recopiée ici faute de pouvoir la lire — mais elle a
/// déjà divergé une fois, sur le web, où l'écran acceptait huit caractères là
/// où l'API en exigeait dix. Le visiteur remplissait tout, cliquait, et
/// recevait un refus qu'il ne pouvait pas comprendre.
const _longueurMotDePasseMin = 6;

/// Créer un compte.
///
/// ## ⚠️ L'INSCRIPTION NE CONNECTE PAS
///
/// Le serveur envoie un lien de confirmation, et le compte n'est utilisable
/// qu'une fois l'adresse vérifiée. Renvoyer vers la boutique comme si tout
/// était fait ferait buter le client **au paiement**, sans qu'il comprenne
/// pourquoi — c'est-à-dire au pire moment.
///
/// On montre donc un écran d'attente explicite, et on **nomme l'adresse** : la
/// faute de frappe est la première cause de « je n'ai rien reçu ».
///
/// ## 🎯 Ce qui manque se dit AVANT le clic
///
/// Un bouton grisé sans explication fait chercher la panne ailleurs — souvent
/// dans la connexion. Et quand le serveur refuse malgré tout, on montre le
/// détail **champ par champ** qu'il renvoie, jamais son message générique :
/// « Certains champs sont invalides » ne dit ni lequel ni pourquoi.
class EcranInscription extends StatefulWidget {
  const EcranInscription({super.key});

  @override
  State<EcranInscription> createState() => _EcranInscriptionState();
}

class _EcranInscriptionState extends State<EcranInscription> {
  final _nom = TextEditingController();
  final _email = TextEditingController();
  final _telephone = TextEditingController();
  final _motDePasse = TextEditingController();

  bool _masque = true;
  bool _envoi = false;
  bool _envoye = false;
  String? _echec;

  @override
  void dispose() {
    _nom.dispose();
    _email.dispose();
    _telephone.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  /// Ce qui manque encore, en une phrase.
  String? get _manque {
    if (_nom.text.trim().isEmpty) {
      return 'Votre nom est nécessaire.';
    }
    if (!_email.text.contains('@')) {
      return 'Entrez une adresse e-mail valide.';
    }
    final reste = _longueurMotDePasseMin - _motDePasse.text.length;
    if (_motDePasse.text.isEmpty) {
      return 'Choisissez un mot de passe.';
    }
    if (reste > 0) {
      return 'Il manque $reste caractère(s) au mot de passe.';
    }
    return null;
  }

  Future<void> _valider() async {
    if (_manque != null || _envoi) return;
    setState(() {
      _envoi = true;
      _echec = null;
    });

    final telephone = _telephone.text.trim();
    try {
      await Services.de(context).api.poster('/api/auth/inscription', {
        'nom': _nom.text.trim(),
        'email': _email.text.trim(),
        // Vide plutôt qu'absent : le serveur accepte les deux, mais une chaîne
        // vide dit « pas de numéro » là où l'absence dit « je ne sais pas ».
        'telephone': telephone.isEmpty ? null : telephone,
        'motDePasse': _motDePasse.text,
      });
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _envoye = true;
      });
    } on ErreurApi catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _echec = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_envoye ? 'Compte créé' : 'Créer un compte')),
      body: _envoye ? _laConfirmation(context) : _leFormulaire(context),
    );
  }

  Widget _laConfirmation(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
    children: [
      const Icon(
        Icons.mark_email_read_outlined,
        size: 56,
        color: Jetons.succes,
      ),
      const SizedBox(height: 20),
      const Text(
        'Vérifiez votre boîte mail',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      Text(
        'Un lien de confirmation est parti vers ${_email.text.trim()}. '
        'Votre compte sera utilisable dès que vous l’aurez ouvert.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, height: 1.55),
      ),
      const SizedBox(height: 12),
      Text(
        // La faute de frappe est la première cause de « je n'ai rien reçu » :
        // on affiche l'adresse au-dessus, et on invite à la relire.
        'Rien reçu ? Regardez dans les indésirables, et vérifiez l’adresse '
        'ci-dessus.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12.5,
          height: 1.5,
          color: context.texteAttenue,
        ),
      ),
      const SizedBox(height: 28),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Retour à la connexion'),
      ),
    ],
  );

  Widget _leFormulaire(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    children: [
      Text(
        'Il faut un compte pour commander, pas pour regarder.',
        style: TextStyle(
          fontSize: 13.5,
          height: 1.5,
          color: context.texteAttenue,
        ),
      ),
      const SizedBox(height: 20),

      const Libelle('Nom'),
      const SizedBox(height: 6),
      TextField(
        controller: _nom,
        textCapitalization: TextCapitalization.words,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(hintText: 'Votre nom'),
      ),

      const SizedBox(height: 16),
      const Libelle('Adresse e-mail'),
      const SizedBox(height: 6),
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        // ⚠️ Sans cette ligne, le clavier met une majuscule au premier
        //    caractère et l'adresse part fausse. Classique sur Android, et
        //    l'utilisateur ne voit pas d'où vient le refus.
        textCapitalization: TextCapitalization.none,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(hintText: 'vous@exemple.com'),
      ),

      const SizedBox(height: 16),
      const Libelle('Téléphone'),
      const SizedBox(height: 6),
      TextField(
        controller: _telephone,
        keyboardType: TextInputType.phone,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(hintText: '+237 6 99 00 00 00'),
      ),
      const SizedBox(height: 4),
      Text(
        'Facultatif.',
        style: TextStyle(fontSize: 11.5, color: context.texteAttenue),
      ),

      const SizedBox(height: 16),
      const Libelle('Mot de passe'),
      const SizedBox(height: 6),
      TextField(
        controller: _motDePasse,
        obscureText: _masque,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _valider(),
        decoration: InputDecoration(
          suffixIcon: IconButton(
            // Le montrer est une AIDE, pas une faille : au clavier tactile, un
            // mot de passe long se tape faux une fois sur deux, et on renonce
            // plutôt que de recommencer à l'aveugle.
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
      const SizedBox(height: 4),
      Text(
        'Au moins $_longueurMotDePasseMin caractères. '
        'Une phrase vaut mieux qu’un mot compliqué.',
        style: TextStyle(fontSize: 11.5, color: context.texteAttenue),
      ),

      const SizedBox(height: 18),
      if (_echec != null) ...[
        Alerte(message: _echec!),
        const SizedBox(height: 12),
      ] else if (_manque != null && _aCommence) ...[
        // Ambre et non rouge : le rouge dit « vous avez fait une faute » à
        // quelqu'un qui est simplement en train de remplir le formulaire.
        Text(
          _manque!,
          style: const TextStyle(fontSize: 12.5, color: Jetons.alerte),
        ),
        const SizedBox(height: 12),
      ],

      FilledButton(
        onPressed: _manque == null && !_envoi ? _valider : null,
        child: Text(_envoi ? 'Création…' : 'Créer mon compte'),
      ),
    ],
  );

  /// Vrai dès qu'on a tapé quelque chose.
  ///
  /// ⚠️ Sans ce garde, « Votre nom est nécessaire » s'afficherait sur un
  ///    formulaire encore vierge — un reproche avant d'avoir rien fait.
  bool get _aCommence =>
      _nom.text.isNotEmpty ||
      _email.text.isNotEmpty ||
      _motDePasse.text.isNotEmpty;
}
