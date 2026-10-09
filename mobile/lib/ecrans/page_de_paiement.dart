import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../widgets/communs.dart';

/// La page de paiement MoneyFusion, ouverte dans l'application (D-55).
///
/// Le client y choisit MTN ou Orange, saisit son numéro et valide. GARAH ne
/// voit rien de ce qui s'y passe : il guette seulement l'**adresse de retour**,
/// vers laquelle MoneyFusion renvoie le client une fois fini.
///
/// Se referme en rendant `true` quand l'adresse de retour est atteinte,
/// `false` (ou `null`) quand le client la ferme lui-même. Dans les deux cas,
/// l'écran appelant **vérifie** l'état auprès du serveur.
///
/// ## 🎯 Atteindre l'adresse de retour ne prouve RIEN
///
/// MoneyFusion y renvoie aussi après une annulation. Ce retour dit seulement
/// « le client a fini sur la page » ; seul le serveur dit si le paiement est
/// passé.
class EcranPageDePaiement extends StatefulWidget {
  const EcranPageDePaiement({super.key, required this.url, this.urlRetour});

  /// La page MoneyFusion, telle que le serveur l'a reçue.
  final String url;

  /// L'adresse de retour fabriquée par le serveur. Nulle : on attend que le
  /// client ferme la page lui-même.
  final String? urlRetour;

  @override
  State<EcranPageDePaiement> createState() => _EcranPageDePaiementState();
}

class _EcranPageDePaiementState extends State<EcranPageDePaiement> {
  late final WebViewController _controleur;

  bool _chargement = true;
  String? _erreur;
  bool _refermee = false;

  @override
  void initState() {
    super.initState();
    _controleur = WebViewController()
      // La page MoneyFusion ne fonctionne pas sans JavaScript.
      //
      // ⚠️ Aucun canal JavaScript n'est ouvert vers l'application : la page
      //    ne peut rien appeler chez nous. Elle s'affiche, c'est tout.
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _decider,
          onPageStarted: (_) {
            if (mounted) setState(() => _chargement = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _chargement = false);
          },
          onWebResourceError: (erreur) {
            // ⚠️ Seule la page PRINCIPALE compte. Une image ou un script tiers
            //    qui échoue ne doit pas remplacer une page de paiement
            //    utilisable par un message d'erreur.
            if (erreur.isForMainFrame != true || !mounted) return;
            setState(() {
              _chargement = false;
              _erreur =
                  'La page de paiement ne se charge pas. Vérifiez votre '
                  'connexion, puis réessayez.';
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  NavigationDecision _decider(NavigationRequest requete) {
    if (_estLeRetour(requete.url)) {
      _refermer(true);
      // On ne charge PAS la boutique web dans la page intégrée : c'est
      // l'écran natif qui prend la suite.
      return NavigationDecision.prevent;
    }

    // ⚠️ Rien d'autre que du https. Un `tel:`, un `intent://` ou un schéma
    //    d'application ouvert ici échouerait dans la page intégrée de toute
    //    façon ; mieux vaut ne pas naviguer que d'afficher une page d'erreur
    //    à la place du formulaire.
    final uri = Uri.tryParse(requete.url);
    if (uri == null || uri.scheme != 'https') {
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  /// L'adresse demandée est-elle celle du retour ?
  ///
  /// ⚠️ On compare l'hôte et le chemin, PAS l'adresse entière : MoneyFusion
  ///    peut ajouter ses propres paramètres à la fin. Une comparaison exacte
  ///    ne reconnaîtrait jamais le retour, et le client resterait sur une
  ///    page blanche de la boutique web.
  bool _estLeRetour(String adresse) {
    final retour = widget.urlRetour;
    if (retour == null || retour.isEmpty) return false;
    final attendu = Uri.tryParse(retour);
    final recu = Uri.tryParse(adresse);
    if (attendu == null || recu == null) return false;
    return recu.host == attendu.host && recu.path == attendu.path;
  }

  void _refermer(bool termine) {
    // Deux navigations vers le retour peuvent se suivre : on ne ferme qu'une
    // fois, sinon le second `pop` fermerait aussi l'écran de paiement.
    if (_refermee || !mounted) return;
    _refermee = true;
    Navigator.of(context).pop(termine);
  }

  void _recharger() {
    setState(() {
      _erreur = null;
      _chargement = true;
    });
    _controleur.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement sécurisé'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Fermer',
          onPressed: () => _refermer(false),
        ),
        bottom: _chargement
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: _erreur == null
          ? WebViewWidget(controller: _controleur)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Alerte(message: _erreur!),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _recharger,
                  child: const Text('Réessayer'),
                ),
              ],
            ),
    );
  }
}
