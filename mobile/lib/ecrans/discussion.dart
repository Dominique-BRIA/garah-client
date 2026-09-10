import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../charte/jetons.dart';
import '../charte/theme.dart';
import '../services/services.dart';
import '../widgets/communs.dart';

/// Le fil d'une discussion : lire la réponse, et répondre.
///
/// ## 🎯 Cet écran n'existait pas
///
/// On pouvait **ouvrir** une discussion depuis une fiche produit, et **voir la
/// liste** de ses discussions. Pas la lire. On écrivait au service client sans
/// jamais pouvoir relire sa réponse — la moitié d'une conversation.
///
/// C'était assumé : le bouton s'appelait « Négocier », et une négociation se
/// lit en comparant des chiffres et des dates, ce qu'un écran de téléphone
/// rend pénible. Mais le bouton pose maintenant une **question**, et une
/// question et sa réponse sont du texte : rien n'empêche plus de les lire ici.
///
/// ## ⚠️ Les propositions de prix ne sont pas ici, et c'est voulu
///
/// Le prix affiché est ferme. Les propositions restent une possibilité du
/// serveur pour le cas rare, traitée depuis le back-office — les faire
/// apparaître chez le client réinstallerait le marchandage qu'on vient d'en
/// retirer.
/// La file personnelle des messages de conversation.
///
/// ⚠️ Le prefixe /utilisateur est resolu par le serveur vers la session de
///    l abonne. Une destination partagee livrerait les discussions d un
///    client a tous les autres connectes.
const String _destinationConversations = '/utilisateur/file/conversations';

class EcranDiscussion extends StatefulWidget {
  const EcranDiscussion({super.key, required this.id, this.sujet});

  final int id;

  /// Le sujet déjà connu de la liste, s'il l'est.
  ///
  /// ⚠️ Il évite un titre vide pendant le chargement. Un écran qui s'ouvre sur
  ///    une barre sans nom donne l'impression de s'être trompé de lien.
  final String? sujet;

  @override
  State<EcranDiscussion> createState() => _EcranDiscussionState();
}

class _EcranDiscussionState extends State<EcranDiscussion> {
  final _reponse = TextEditingController();
  final _defilement = ScrollController();

  Map<String, dynamic>? _fil;
  bool _chargement = true;
  bool _envoi = false;
  String? _erreur;

  /// Coupe l ecoute temps reel. Nul tant que l ecran ne s est pas monte.
  void Function()? _couperEcoute;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ⚠️ ICI et non dans initState : Services.de() lit un InheritedWidget,
    //    ce qui est interdit avant que les dependances ne soient posees.
    _couperEcoute ??= Services.de(
      context,
    ).tempsReel.abonner(_destinationConversations, _surMessageRecu);
  }

  @override
  void dispose() {
    // ⚠️ On COUPE. Sans cela, chaque discussion ouverte laisserait un
    //    abonnement de plus derriere elle — et un telephone qui garde une
    //    prise ouverte pour rien reveille sa radio et vide sa batterie.
    _couperEcoute?.call();
    _reponse.dispose();
    _defilement.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _messages =>
      ((_fil?['messages'] as List<dynamic>?) ?? const [])
          .map((e) => e as Map<String, dynamic>)
          .toList();

  bool get _close => (_fil?['statut'] as String?) == 'CLOSED';

  /// L'arrivée d'un message, en direct.
  ///
  /// ## 🎯 Il fallait tirer sur l'écran pour voir la réponse
  ///
  /// Le client posait sa question et attendait devant un écran figé. Rien ne
  /// disait si quelqu'un avait répondu — il fallait recharger pour savoir, et
  /// donc recharger sans cesse.
  ///
  /// ## ⚠️ LE MESSAGE EST AJOUTÉ, LE FIL N'EST PAS RELU
  ///
  /// Redemander le fil entier à chaque phrase ferait une requête par message —
  /// exactement ce que le temps réel évite. Sur un forfait compté, la
  /// différence se voit sur la facture.
  ///
  /// ## ⚠️ On se protège du doublon
  ///
  /// Le serveur pousse aux deux bouts, y compris à l'expéditeur : la même
  /// discussion peut être ouverte ici et sur le navigateur. L'identifiant
  /// tranche.
  void _surMessageRecu(Map<String, dynamic> message) {
    if (!mounted || _fil == null) {
      return;
    }
    if (message['conversationId'] != widget.id) {
      return;
    }
    if (_messages.any((m) => m['id'] == message['id'])) {
      return;
    }

    setState(() {
      _fil = {
        ..._fil!,
        'messages': [..._messages, message],
      };
    });
    _versLeBas();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      final fil =
          await Services.de(
                context,
              ).api.obtenir('/api/conversations/${widget.id}')
              as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _fil = fil;
        _chargement = false;
      });
      _versLeBas();
    } on ErreurApi catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.message;
      });
    } catch (_) {
      // Le filet : tout ce qui casse APRÈS la réponse — un champ absent, un
      // cast qui échoue — laisserait sinon l'écran tourner sans message.
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = 'Une erreur inattendue est survenue. Reessayez.';
      });
    }
  }

  Future<void> _envoyer() async {
    final texte = _reponse.text.trim();
    if (texte.isEmpty || _envoi) return;

    final messager = ScaffoldMessenger.of(context);
    final api = Services.de(context).api;
    setState(() => _envoi = true);

    try {
      final message =
          await api.poster('/api/conversations/${widget.id}/messages', {
                'contenu': texte,
              })
              as Map<String, dynamic>;
      if (!mounted) return;

      // ⚠️ On ajoute le message rendu par le SERVEUR, pas le texte saisi : lui
      //    seul porte l'identifiant de l'expéditeur et la date, et c'est ce
      //    qui le range du bon côté du fil au prochain rendu.
      setState(() {
        _fil = {
          ...?_fil,
          'messages': [..._messages, message],
        };
        _envoi = false;
      });
      _reponse.clear();
      _versLeBas();
    } on ErreurApi catch (e) {
      if (!mounted) return;
      setState(() => _envoi = false);
      messager.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _envoi = false);
      messager.showSnackBar(
        const SnackBar(
          content: Text('Une erreur inattendue est survenue. Reessayez.'),
        ),
      );
    }
  }

  /// ⚠️ Après le premier rendu : sinon la liste n'a pas encore sa hauteur et
  ///    le défilement ne va nulle part.
  void _versLeBas() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_defilement.hasClients) return;
      _defilement.jumpTo(_defilement.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final moi = Services.de(context).session.utilisateurId;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          (_fil?['sujet'] as String?) ?? widget.sujet ?? 'Discussion',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator())
                : _erreur != null
                ? EtatVide(
                    message: _erreur!,
                    libelleAction: 'Réessayer',
                    surAction: _charger,
                  )
                : _messages.isEmpty
                ? const EtatVide(message: 'Cette discussion est vide.')
                : RefreshIndicator(
                    onRefresh: _charger,
                    child: ListView.builder(
                      controller: _defilement,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) =>
                          _uneBulle(context, _messages[i], moi),
                    ),
                  ),
          ),
          if (!_chargement && _erreur == null) _laReponse(context),
        ],
      ),
    );
  }

  /// Une bulle, rangée à gauche ou à droite selon qui parle.
  ///
  /// ⚠️ La comparaison porte sur l'identifiant, pas sur un rôle : un fil peut
  ///    passer d'un conseiller à un autre, et « ce n'est pas moi » est la
  ///    seule chose qui reste vraie.
  Widget _uneBulle(BuildContext context, Map<String, dynamic> m, int? moi) {
    final auteur = (m['expediteurId'] as num?)?.toInt();
    final deMoi = moi != null && auteur == moi;
    final date = DateTime.tryParse((m['dateEnvoi'] as String?) ?? '');
    final fond = deMoi
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surface;

    return Align(
      alignment: deMoi ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: fond,
          border: Border.all(color: context.bordure),
          borderRadius: BorderRadius.circular(Jetons.rayonMoyen),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (m['contenu'] as String?) ?? '',
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),
            if (date != null) ...[
              const SizedBox(height: 6),
              Text(
                _quand(date),
                style: TextStyle(fontSize: 11, color: context.texteAttenue),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _laReponse(BuildContext context) {
    if (_close) {
      // ⚠️ On DIT que c'est clos plutôt que de laisser un champ qui refuserait
      //    à l'envoi. Un formulaire qui accepte la saisie puis la rejette fait
      //    perdre le texte écrit.
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Text(
            'Cette discussion est close. Ouvrez-en une nouvelle depuis la '
            'fiche de l’article si vous avez une autre question.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: context.texteAttenue,
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _reponse,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Votre message…'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _reponse.text.trim().isEmpty || _envoi
                  ? null
                  : _envoyer,
              icon: _envoi
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  /// « aujourd'hui à 14:05 » plutôt qu'une date complète.
  ///
  /// Dans un fil, l'heure est ce qu'on cherche ; la date ne sert qu'à situer
  /// ce qui n'est pas d'aujourd'hui.
  static String _quand(DateTime d) {
    final maintenant = DateTime.now();
    String deuxChiffres(int n) => n.toString().padLeft(2, '0');
    final heure = '${deuxChiffres(d.hour)}:${deuxChiffres(d.minute)}';

    if (d.year == maintenant.year &&
        d.month == maintenant.month &&
        d.day == maintenant.day) {
      return 'aujourd’hui à $heure';
    }
    return '${deuxChiffres(d.day)}/${deuxChiffres(d.month)}/${d.year} à $heure';
  }
}
