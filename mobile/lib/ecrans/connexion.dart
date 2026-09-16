import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../charte/jetons.dart';
import '../charte/theme.dart';
import '../services/services.dart';
import '../widgets/communs.dart';
import 'connexion_whatsapp.dart';
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

  /// Séparé de [_envoi], volontairement.
  ///
  /// Les deux boutons se désactivent ensemble — on ne lance pas deux
  /// connexions —, mais un seul doit afficher « Connexion… ». Un indicateur
  /// unique ferait tourner le bouton Google pendant qu'on valide un mot de
  /// passe, et inversement.
  bool _envoiGoogle = false;

  /// Vrai quand le bouton Google peut être proposé.
  ///
  /// Faux tant que la configuration n'est pas revenue, et faux pour toujours
  /// si l'API n'annonce aucun identifiant. 🎯 **On n'affiche pas un bouton qui
  /// échouerait à coup sûr** : c'est « dire ce qui manque avant le clic », pris
  /// du côté de celui qui propose.
  bool _googleDisponible = false;

  /// Vrai quand Meta est configuré côté serveur.
  ///
  /// Même règle que Google : on n'affiche pas un bouton qui échouerait. La
  /// vérification Meta Business prend des semaines — jusque-là, le bouton
  /// n'existe pas, et l'application se comporte comme avant.
  bool _whatsappDisponible = false;

  @override
  void initState() {
    super.initState();
    // ⚠️ Pas dans initState directement : Services.de() a besoin d'un context
    //    déjà monté dans l'arbre. Le post-frame le garantit.
    WidgetsBinding.instance.addPostFrameCallback((_) => _preparerGoogle());
  }

  /// ⚠️ Ici, et **pas** au démarrage de l'application.
  ///
  /// `preparer()` interroge l'API. Le faire au lancement retarderait la
  /// première image pour une fonctionnalité dont on n'a besoin que sur cet
  /// écran — et rendrait l'ouverture de la boutique dépendante du réseau,
  /// alors que la vitrine doit s'afficher hors connexion.
  Future<void> _preparerGoogle() async {
    if (!mounted) return;
    final services = Services.de(context);
    await services.google.preparer();

    // ⚠️ `charger()` ne relance rien : la configuration est lue une seule fois
    //    et partagée. `preparer()` vient déjà de la demander.
    await services.configuration.charger();

    if (!mounted) return;
    setState(() {
      _googleDisponible = services.google.disponible;
      _whatsappDisponible = services.configuration.whatsappDisponible;
    });
  }

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

  /// « Continuer avec Google ».
  ///
  /// Trois issues, et la première est celle qu'on oublie :
  ///
  /// ```text
  /// annulation   jeton null  → on remet l ecran comme avant, SANS message
  /// echec        ErreurApi   → on affiche, comme pour le mot de passe
  /// succes                   → on ferme l ecran, comme pour le mot de passe
  /// ```
  ///
  /// 🎯 **Annuler n'est pas échouer.** Afficher « connexion impossible » en
  /// rouge parce que quelqu'un a fermé la feuille Google d'un geste laisse
  /// croire à une panne, et décourage de réessayer.
  Future<void> _continuerAvecGoogle() async {
    if (_envoi || _envoiGoogle) return;
    setState(() {
      _envoiGoogle = true;
      _echec = null;
    });

    final services = Services.de(context);
    final navigateur = Navigator.of(context);
    try {
      final jeton = await services.google.obtenirLeJeton();

      if (jeton == null) {
        // Annulation. On rend simplement l'écran à son état d'avant.
        if (mounted) setState(() => _envoiGoogle = false);
        return;
      }

      await services.session.connecterAvecGoogle(jeton);
      if (mounted) navigateur.pop();
    } on ErreurApi catch (e) {
      if (!mounted) return;
      setState(() {
        _envoiGoogle = false;
        _echec = e.message;
      });
    } catch (_) {
      // Le même filet que _connecter, et pour la même raison : tout ce qui
      // casse APRÈS la réponse lève autre chose qu'une ErreurApi, et le
      // bouton tournerait indéfiniment sans message.
      if (!mounted) return;
      setState(() {
        _envoiGoogle = false;
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
            onPressed: _manque == null && !_envoi && !_envoiGoogle
                ? _connecter
                : null,
            child: Text(_envoi ? 'Connexion…' : 'Se connecter'),
          ),

          // ⚠️ Le séparateur apparaît dès qu'AU MOINS un bouton suit.
          //    Affiché seul, il annoncerait un choix qui n'existe pas.
          if (_googleDisponible || _whatsappDisponible) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Divider(color: context.texteAttenue)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'ou',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: context.texteAttenue,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: context.texteAttenue)),
              ],
            ),
            const SizedBox(height: 18),
            if (_googleDisponible)
              OutlinedButton.icon(
                onPressed: !_envoi && !_envoiGoogle
                    ? _continuerAvecGoogle
                    : null,
                icon: const Text(
                  'G',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    // Le bleu de Google. Une lettre plutôt qu'un logo :
                    // embarquer l'image officielle ajoute un fichier à l'APK et
                    // impose des règles d'usage de marque qu'on ne veut pas
                    // suivre de travers.
                    color: Color(0xFF4285F4),
                  ),
                ),
                label: Text(
                  _envoiGoogle ? 'Connexion…' : 'Continuer avec Google',
                ),
              ),

            if (_googleDisponible && _whatsappDisponible)
              const SizedBox(height: 10),

            // ⚠️ Ce bouton n'ouvre AUCUN SDK : il mène à un écran qui demande
            //    un numéro. Meta n'expose aucune API de connexion — le nom
            //    correspond à ce que la personne comprend, pas à ce qui se
            //    passe (D-51).
            if (_whatsappDisponible)
              OutlinedButton.icon(
                onPressed: _envoi || _envoiGoogle
                    ? null
                    : () async {
                        final entre = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => const EcranConnexionWhatsApp(),
                          ),
                        );
                        // L'écran WhatsApp a ouvert la session : on ferme
                        // celui-ci aussi, pour rendre la main là où la
                        // personne avait cliqué « Se connecter ».
                        if (entre == true && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                icon: const Icon(
                  Icons.chat_bubble_outline,
                  size: 19,
                  // Le vert de WhatsApp, pour la même raison que le G bleu.
                  color: Color(0xFF25D366),
                ),
                label: const Text('Continuer avec WhatsApp'),
              ),

            const SizedBox(height: 10),
            // 🎯 Dire ce qui va se passer AVANT le clic. Sans cette phrase,
            //    quelqu'un qui n'a pas de compte hésite à appuyer, croyant
            //    que le bouton n'est là que pour se reconnecter.
            Text(
              'Si vous n\'avez pas encore de compte, il sera créé.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: context.texteAttenue),
            ),
          ],

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
