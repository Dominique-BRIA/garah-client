import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../charte/jetons.dart';
import '../charte/theme.dart';
import '../services/services.dart';
import '../widgets/communs.dart';
import 'connexion.dart';
import 'discussion.dart';

class _Dossier {
  const _Dossier({
    required this.numero,
    required this.titre,
    required this.texte,
    required this.statut,
    required this.date,
  });

  final String numero;
  final String titre;
  final String texte;
  final String statut;
  final DateTime? date;
}

const _statutsReclamation = <String, ({String texte, Color? couleur})>{
  // ⚠️ Les codes du serveur ne s'affichent jamais tels quels : ils
  //    apprendraient au client un vocabulaire interne qui n'est pas le sien,
  //    et qui changera sans qu'on le prévienne.
  'OUVERTE': (texte: 'Reçue', couleur: Jetons.alerte),
  'EN_COURS': (texte: 'En cours d’examen', couleur: Jetons.info),
  'RESOLUE': (texte: 'Résolue', couleur: Jetons.succes),
  'FERMEE': (texte: 'Close', couleur: null),
};

const _statutsRetour = <String, ({String texte, Color? couleur})>{
  'DEMANDE': (texte: 'Demandé', couleur: Jetons.alerte),
  'ACCEPTE': (texte: 'Accepté', couleur: Jetons.info),
  'REFUSE': (texte: 'Refusé', couleur: null),
  'RECEPTIONNE': (texte: 'Colis reçu', couleur: Jetons.info),
  'VALIDE': (texte: 'Remboursement validé', couleur: Jetons.succes),
  'CLOTURE': (texte: 'Clos', couleur: null),
};

/// Réclamations et retours, sur deux onglets.
///
/// ## Pourquoi ensemble
///
/// Ce sont les deux voies de recours, et le client ne sait pas toujours
/// laquelle est la sienne : « il manque un article » est une réclamation,
/// « je renvoie celui-ci » est un retour. Les séparer en deux entrées de menu
/// obligerait à choisir avant d'avoir compris la différence.
///
/// ## ⚠️ Ni l'une ni l'autre ne promet quoi que ce soit
///
/// Ouvrir un dossier ne rembourse rien. L'écran le dit, sous peine de faire
/// attendre un virement qui ne viendra pas — et l'attente se transforme en
/// seconde réclamation, puis en appel téléphonique.
class EcranSav extends StatefulWidget {
  const EcranSav({super.key});

  @override
  State<EcranSav> createState() => _EcranSavState();
}

class _EcranSavState extends State<EcranSav> {
  List<_Dossier> _reclamations = const [];
  List<_Dossier> _retours = const [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });

    final api = Services.de(context).api;
    try {
      final r = await api.obtenir('/api/sav/reclamations/miennes?taille=50');
      _reclamations = ((r as Map<String, dynamic>)['content'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .map(
            (j) => _Dossier(
              numero: (j['numero'] as String?) ?? '',
              titre: (j['motif'] as String?) ?? '',
              texte: (j['description'] as String?) ?? '',
              statut: (j['statut'] as String?) ?? '',
              date: DateTime.tryParse((j['dateCreation'] as String?) ?? ''),
            ),
          )
          .toList();

      final t = await api.obtenir('/api/sav/retours/miens?taille=50');
      _retours = ((t as Map<String, dynamic>)['content'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .map(
            (j) => _Dossier(
              numero: (j['numero'] as String?) ?? '',
              titre: (j['motif'] as String?) ?? '',
              texte: '',
              statut: (j['statut'] as String?) ?? '',
              date: DateTime.tryParse((j['dateCreation'] as String?) ?? ''),
            ),
          )
          .toList();

      if (!mounted) return;
      setState(() => _chargement = false);
    } on ErreurApi catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.message;
      });
    } catch (_) {
      // 🎯 LE FILET, derive de la branche ci-dessus.
      //
      //    Ne rattraper que `ErreurApi` semble propre : c'est ce que leve la
      //    couche reseau. Mais tout ce qui casse APRES la reponse — un champ
      //    absent, un cast qui echoue — leve autre chose, l'exception
      //    s'echappe, et l'indicateur d'attente reste arme : l'ecran tourne
      //    indefiniment SANS message.
      //
      //    C'est exactement ce qui rendait la connexion impossible sur mobile.
      //    Le defaut etait ici aussi, dans chaque ecran, en attente.
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = 'Une erreur inattendue est survenue. Reessayez.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Réclamations et retours'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Réclamations'),
              Tab(text: 'Retours'),
            ],
          ),
        ),
        body: _chargement
            ? const Center(child: CircularProgressIndicator())
            : _erreur != null
            ? EtatVide(
                message: _erreur!,
                libelleAction: 'Réessayer',
                surAction: _charger,
              )
            : TabBarView(
                children: [
                  _liste(
                    context,
                    _reclamations,
                    _statutsReclamation,
                    vide: 'Vous n’avez ouvert aucune réclamation.',
                    aide:
                        'Une réclamation s’ouvre depuis la version web, sur la '
                        'commande concernée. Un conseiller examine chaque '
                        'dossier — l’ouvrir ne déclenche aucun remboursement.',
                  ),
                  _liste(
                    context,
                    _retours,
                    _statutsRetour,
                    vide: 'Vous n’avez demandé aucun retour.',
                    aide:
                        'Un retour se demande depuis la version web, en '
                        'désignant les articles concernés. L’état que vous '
                        'indiquez est vérifié à l’ouverture du colis : le '
                        'montant remboursé est arrêté à ce moment-là.',
                  ),
                ],
              ),
      ),
    );
  }

  Widget _liste(
    BuildContext context,
    List<_Dossier> dossiers,
    Map<String, ({String texte, Color? couleur})> statuts, {
    required String vide,
    required String aide,
  }) {
    if (dossiers.isEmpty) {
      return EtatVide(message: vide, detail: aide);
    }

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          for (final d in dossiers) _uneCarte(context, d, statuts),
          const SizedBox(height: 10),
          Text(
            aide,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: context.texteAttenue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _uneCarte(
    BuildContext context,
    _Dossier d,
    Map<String, ({String texte, Color? couleur})> statuts,
  ) {
    final etat = statuts[d.statut];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: context.bordure),
        borderRadius: BorderRadius.circular(Jetons.rayonMoyen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  d.numero,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Etiquette(texte: etat?.texte ?? d.statut, couleur: etat?.couleur),
            ],
          ),
          if (d.titre.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              d.titre,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
          if (d.texte.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              d.texte,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: context.texteAttenue,
              ),
            ),
          ],
          if (d.date != null) ...[
            const SizedBox(height: 6),
            Text(
              'Ouvert le ${_jour(d.date!)}',
              style: TextStyle(fontSize: 11.5, color: context.texteAttenue),
            ),
          ],
        ],
      ),
    );
  }

  static String _jour(DateTime d) {
    final l = d.toLocal();
    String deux(int n) => n.toString().padLeft(2, '0');
    return '${deux(l.day)}/${deux(l.month)}/${l.year}';
  }
}

/// Mes discussions.
///
/// ## ⚠️ La liste seule ne suffisait pas
///
/// Elle répondait à « est-ce qu'on m'a répondu ? » sans permettre de LIRE la
/// réponse : le fil vivait uniquement sur la version web. C'était assumé tant
/// que le bouton s'appelait « Négocier » — une négociation se lit en comparant
/// des chiffres et des dates, ce qu'un petit écran rend pénible.
///
/// Le bouton pose maintenant une question. Une question et sa réponse sont du
/// texte : `EcranDiscussion` les ouvre d'une tape sur une carte.
class EcranDiscussions extends StatefulWidget {
  const EcranDiscussions({super.key});

  @override
  State<EcranDiscussions> createState() => _EcranDiscussionsState();
}

class _EcranDiscussionsState extends State<EcranDiscussions> {
  static const _statuts = <String, ({String texte, Color? couleur})>{
    // Ouverte par GARAH pour prevenir (un colis parti). Personne n'attend de
    // reponse — mais le client peut en ecrire une, et un conseiller la lira.
    'INFORMATION': (texte: 'Information', couleur: Jetons.info),
    'WAITING': (texte: 'En attente d’un conseiller', couleur: Jetons.alerte),
    'ASSIGNED': (texte: 'Un conseiller vous suit', couleur: Jetons.info),
    'CLOSED': (texte: 'Close', couleur: null),
  };

  List<Map<String, dynamic>> _conversations = const [];
  bool _chargement = true;
  String? _erreur;

  /// Le compte dont on a déjà chargé les discussions.
  ///
  /// ⚠️ Cet écran est maintenant un ONGLET, monté dès l'ouverture de
  ///    l'application — connecté ou non. Charger dans initState enverrait une
  ///    requête sans session, et l'écran afficherait une erreur à quelqu'un
  ///    qui n'a simplement pas encore de compte. On charge au moment où une
  ///    session existe, et une seule fois par compte.
  int? _chargePour;

  /// Vrai pendant l'envoi de la première question à l'Assistance.
  bool _envoiAssistance = false;

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      final page =
          await Services.de(
                context,
              ).api.obtenir('/api/conversations/miennes?taille=50')
              as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _conversations = (page['content'] as List<dynamic>)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        _chargement = false;
      });
    } on ErreurApi catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.message;
      });
    } catch (_) {
      // 🎯 LE FILET, derive de la branche ci-dessus.
      //
      //    Ne rattraper que `ErreurApi` semble propre : c'est ce que leve la
      //    couche reseau. Mais tout ce qui casse APRES la reponse — un champ
      //    absent, un cast qui echoue — leve autre chose, l'exception
      //    s'echappe, et l'indicateur d'attente reste arme : l'ecran tourne
      //    indefiniment SANS message.
      //
      //    C'est exactement ce qui rendait la connexion impossible sur mobile.
      //    Le defaut etait ici aussi, dans chaque ecran, en attente.
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = 'Une erreur inattendue est survenue. Reessayez.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = Services.de(context).session;

    return Scaffold(
      appBar: AppBar(title: const Text('Mes discussions')),
      body: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          if (session.enCoursDeReprise) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!session.connecte) {
            _chargePour = null;
            // ⚠️ Un onglet ouvert à tous : sans session, on dit POURQUOI la
            //    liste est vide et comment la remplir, plutôt qu'une erreur.
            return EtatVide(
              message: 'Connectez-vous pour retrouver vos discussions.',
              detail:
                  'Vos questions sur un article, et les réponses de nos '
                  'conseillers, arrivent ici.',
              libelleAction: 'Se connecter',
              surAction: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const EcranConnexion())),
            );
          }

          final id = session.utilisateurId;
          if (_chargePour != id) {
            _chargePour = id;
            // Après le rendu : appeler setState pendant un build lèverait.
            WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
          }

          return _corps(context);
        },
      ),
    );
  }

  Widget _corps(BuildContext context) {
    if (_chargement) return const Center(child: CircularProgressIndicator());
    if (_erreur != null) {
      return EtatVide(
        message: _erreur!,
        libelleAction: 'Réessayer',
        surAction: _charger,
      );
    }

    final assistance = _conversations
        .where((c) => c['assistance'] == true)
        .firstOrNull;
    final autres = _conversations
        .where((c) => c['assistance'] != true)
        .toList();

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          // 🎯 L'ASSISTANCE GARAH, ÉPINGLÉE EN TÊTE. Jusqu'ici une discussion
          //    ne naissait que du bouton « Contacter » d'une fiche produit :
          //    pour une question sur une livraison ou un compte, il n'y avait
          //    pas de porte. Celle-ci est toujours là, et c'est aussi par elle
          //    que GARAH écrit au client.
          _carteAssistance(context, assistance),
          const SizedBox(height: 18),
          if (autres.isEmpty)
            Text(
              'Vos autres discussions apparaîtront ici. Le bouton « Contacter » '
              'd’une fiche produit en ouvre une.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: context.texteAttenue,
              ),
            )
          else ...[
            for (final c in autres) _uneCarte(context, c),
            const SizedBox(height: 10),
            Text(
              'Touchez une discussion pour la lire et répondre.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: context.texteAttenue,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _carteAssistance(BuildContext context, Map<String, dynamic>? a) {
    final aide = switch (a?['statut'] as String?) {
      'WAITING' => 'En attente d’un conseiller',
      'ASSIGNED' => 'Un conseiller vous suit',
      _ => 'Une question ? Écrivez-nous, à tout moment.',
    };

    return InkWell(
      onTap: _envoiAssistance ? null : () => _ouvrirAssistance(a),
      borderRadius: BorderRadius.circular(Jetons.rayonMoyen),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Jetons.primaire.withValues(alpha: 0.07),
          border: Border.all(color: Jetons.primaire.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(Jetons.rayonMoyen),
        ),
        child: Row(
          children: [
            Icon(Icons.support_agent, color: context.primaireTexte, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Assistance GARAH',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    aide,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: context.texteAttenue,
                    ),
                  ),
                ],
              ),
            ),
            if (_envoiAssistance)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.chevron_right, color: context.texteAttenue),
          ],
        ),
      ),
    );
  }

  /// Ouvre l'Assistance — ou la fait naître de la première question.
  ///
  /// ⚠️ Elle NAÎT DU PREMIER MESSAGE, jamais d'un simple appui : créée à
  ///    l'ouverture, elle laisserait un dossier vide chez l'équipe à chaque
  ///    fois qu'un client la regarde sans rien écrire.
  Future<void> _ouvrirAssistance(Map<String, dynamic>? existante) async {
    final navigateur = Navigator.of(context);
    final messager = ScaffoldMessenger.of(context);
    final api = Services.de(context).api;

    var id = (existante?['id'] as num?)?.toInt();

    if (id == null) {
      final texte = await showDialog<String>(
        context: context,
        builder: (_) => const _PremiereQuestion(),
      );
      if (texte == null || texte.isEmpty || !mounted) return;

      setState(() => _envoiAssistance = true);
      try {
        final m =
            await api.poster('/api/conversations/assistance/messages', {
                  'contenu': texte,
                })
                as Map<String, dynamic>;
        id = (m['conversationId'] as num).toInt();
      } on ErreurApi catch (e) {
        if (!mounted) return;
        setState(() => _envoiAssistance = false);
        messager.showSnackBar(SnackBar(content: Text(e.message)));
        return;
      } catch (_) {
        if (!mounted) return;
        setState(() => _envoiAssistance = false);
        messager.showSnackBar(
          const SnackBar(
            content: Text('Votre message n’a pas pu partir. Réessayez.'),
          ),
        );
        return;
      }
      if (!mounted) return;
      setState(() => _envoiAssistance = false);
    }

    final aOuvrir = id;
    await navigateur.push(
      MaterialPageRoute(
        builder: (_) => EcranDiscussion(id: aOuvrir, sujet: 'Assistance GARAH'),
      ),
    );
    // Au retour, l'état a pu changer : un conseiller a pu la prendre.
    if (mounted) _charger();
  }

  Widget _uneCarte(BuildContext context, Map<String, dynamic> c) {
    final etat = _statuts[c['statut'] as String? ?? ''];
    final date = DateTime.tryParse((c['dateCreation'] as String?) ?? '');

    final sujet = (c['sujet'] as String?) ?? '';

    return InkWell(
      // ⚠️ Le sujet est passé pour que la barre du fil porte un nom AVANT que
      //    la réponse n'arrive. Un écran qui s'ouvre sans titre donne
      //    l'impression de s'être trompé de lien.
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              EcranDiscussion(id: (c['id'] as num).toInt(), sujet: sujet),
        ),
      ),
      borderRadius: BorderRadius.circular(Jetons.rayonMoyen),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: context.bordure),
          borderRadius: BorderRadius.circular(Jetons.rayonMoyen),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sujet,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (date != null)
                  Text(
                    'Ouverte le ${_EcranSavState._jour(date)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.texteAttenue,
                    ),
                  ),
                Etiquette(
                  texte: etat?.texte ?? (c['statut'] as String? ?? ''),
                  couleur: etat?.couleur,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// La première question à l'Assistance GARAH.
///
/// ⚠️ Un widget à état pour une seule raison : il possède son contrôleur de
///    saisie, et doit le libérer. Un contrôleur créé par l'appelant pour une
///    boîte de dialogue fuirait à chaque ouverture.
class _PremiereQuestion extends StatefulWidget {
  const _PremiereQuestion();

  @override
  State<_PremiereQuestion> createState() => _PremiereQuestionState();
}

class _PremiereQuestionState extends State<_PremiereQuestion> {
  final _texte = TextEditingController();

  @override
  void dispose() {
    _texte.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assistance GARAH'),
      content: TextField(
        controller: _texte,
        autofocus: true,
        minLines: 3,
        maxLines: 6,
        maxLength: 5000,
        decoration: const InputDecoration(
          hintText:
              'Votre question, sur une commande, un paiement, votre compte…',
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _texte.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_texte.text.trim()),
          child: const Text('Envoyer'),
        ),
      ],
    );
  }
}
